class_name HintPlumes
extends MultiMeshInstance3D
## The restoration hints' plumes (owner, 2026-10-06; RestoreHints): a tall, wispy column of soft pink
## haze rising from each target, tall enough to show over the ball's curve. One draw call for all of
## them; a fixed pool of SLOTS (old ones are reused), so nothing builds up.

const SLOTS := 8
const LIFE_S := 2.8

var _age: Array[float] = []
var _next := 0


func _init() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	mm.mesh = q
	mm.instance_count = SLOTS
	mm.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/hint_plume.gdshader")
	m.set_shader_parameter("col", RestoreHints.COL)
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	for i in SLOTS:
		_age.append(-1.0)
		_hide(i)
	visible = false


## A plume rising from `foot` along `up`.
func emit(foot: Vector3, up: Vector3) -> void:
	var i := _next
	_next = (_next + 1) % SLOTS
	_age[i] = 0.0
	multimesh.set_instance_transform(i, Transform3D(Basis(), foot))
	multimesh.set_instance_custom_data(i, Color(up.x, up.y, up.z, 0.0))
	visible = true


## How many are rising now (tests).
func live() -> int:
	var n := 0
	for a in _age:
		if a >= 0.0:
			n += 1
	return n


func _hide(i: int) -> void:
	multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -9999, 0)))
	multimesh.set_instance_custom_data(i, Color(0, 1, 0, 1.0))


func _process(dt: float) -> void:
	if not visible:
		return
	var any := false
	for i in SLOTS:
		if _age[i] < 0.0:
			continue
		_age[i] += dt
		if _age[i] >= LIFE_S:
			_age[i] = -1.0
			_hide(i)
			continue
		any = true
		var c := multimesh.get_instance_custom_data(i)
		c.a = _age[i] / LIFE_S
		multimesh.set_instance_custom_data(i, c)
	visible = any
