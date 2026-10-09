class_name GuideBubbles
extends MultiMeshInstance3D
## The restoration hints' guide (owner, 2026-10-06; RestoreHints): a little string of bubbles leaves
## Gill toward what is left to restore. Not a rigid clump: COUNT bubbles follow one another like a
## small snake along the ball's curve, each weaving and bobbing on its own, and they pop one at a time,
## out of order, until none is left. Purely cosmetic: its own random generator (never the gameplay
## sequence), a fixed handful of bubbles, nothing left behind.

const COUNT := 6
## How far the head travels along the ball (m) and how long that takes (s).
const TRAVEL_M := 9.0
const LIFE_S := 3.4
## Each bubble trails the one before it by this much of the path (s of travel).
const GAP_S := 0.14
const SIZE := 0.2
## The first pop comes after this share of LIFE_S; the last at LIFE_S.
const FIRST_POP := 0.35

static var _rng := RandomNumberGenerator.new()

var t := 0.0
var active := false
var _center := Vector3.ZERO
var _r := 1.0
var _up0 := Vector3.UP
var _axis := Vector3.RIGHT
var _side := Vector3.FORWARD
var _phase: Array[float] = []
var _amp: Array[float] = []
var _pop_at: Array[float] = []
var _size: Array[float] = []
var _popped: Array[bool] = []
## For tests: how many are still unpopped.
var alive := 0


func _init() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	mm.mesh = q
	mm.instance_count = COUNT
	mm.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/hint_bubble.gdshader")
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	visible = false


## Sends the string from `from` (just above Gill) toward `toward`, round the ball centred at `center`.
func launch(center: Vector3, from: Vector3, toward: Vector3) -> void:
	_center = center
	_r = (from - center).length()
	_up0 = (from - center) / _r
	var d := toward - from
	d = (d - _up0 * d.dot(_up0))
	if d.length() < 0.001:
		d = MossBall.frame_at(_up0, 0.0).z
	d = d.normalized()
	_axis = _up0.cross(d).normalized()
	_side = _axis
	_phase.clear()
	_amp.clear()
	_pop_at.clear()
	_size.clear()
	_popped.clear()
	for i in COUNT:
		_popped.append(false)
		_phase.append(_rng.randf_range(0.0, TAU))
		_amp.append(_rng.randf_range(0.12, 0.3))
		_size.append(SIZE * _rng.randf_range(0.75, 1.25))
	# Pops: spread between FIRST_POP and the end, shuffled so they go out of order.
	var times: Array[float] = []
	for i in COUNT:
		times.append(lerpf(LIFE_S * FIRST_POP, LIFE_S, (i + _rng.randf_range(0.0, 0.8)) / COUNT))
	times.shuffle()
	_pop_at = times
	t = 0.0
	active = true
	alive = COUNT
	visible = true
	_update()


## Where bubble `i` is at time `tt`: along the curve behind the head, weaving sideways and bobbing.
func bubble_pos(i: int, tt: float) -> Vector3:
	var s := maxf(tt - i * GAP_S, 0.0)
	# (Eases out: quick from his body, slowing as it goes.)
	var k := 1.0 - pow(1.0 - clampf(s / LIFE_S, 0.0, 1.0), 1.6)
	var ang := k * TRAVEL_M / _r
	var up := _up0.rotated(_axis, ang)
	var weave := sin(tt * 5.2 + _phase[i] - i * 0.9) * _amp[i] * (0.4 + k)
	var bob := sin(tt * 3.7 + _phase[i] * 1.7) * 0.12 + k * 0.5
	return _center + up * (_r + bob) + _side * weave


func _process(dt: float) -> void:
	if not active:
		return
	t += dt
	_update()


func _update() -> void:
	var mm := multimesh
	alive = 0
	for i in COUNT:
		var born := t >= i * GAP_S * 0.6
		var p_at := _pop_at[i]
		if not born or t >= p_at + 0.12:
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), Vector3(0, -9999, 0)))
			mm.set_instance_color(i, Color(1, 1, 1, 0))
			if born and t >= p_at + 0.12 and not _popped[i]:
				# Popped: a tiny sparkle where it was, once.
				if WaterFX.inst != null:
					WaterFX.inst.sparkle(bubble_pos(i, p_at), Color(0.9, 0.98, 1.0, 0.8), 4, 0.6, 0.03, 0.35)
				_popped[i] = true
			continue
		alive += 1
		var sz := _size[i]
		var a := clampf(t / 0.15, 0.0, 1.0)
		if t >= p_at:
			# The pop: a quick swell and fade.
			var u := (t - p_at) / 0.12
			sz *= 1.0 + u * 0.8
			a *= 1.0 - u
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * sz), bubble_pos(i, t)))
		mm.set_instance_color(i, Color(1, 1, 1, a))
	if t >= LIFE_S + 0.2:
		active = false
		visible = false
		alive = 0
