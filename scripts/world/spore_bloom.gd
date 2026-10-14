class_name SporeBloom
extends Node3D
## A toxic spore bloom (owner, 2026-10-06): a sickly growth on an unhealthy, otherwise empty patch of a
## moss ball. Now and then it swells, glows and hisses (WARN_S: time to notice and step away), then
## bursts and lets out a low yellow mist that creeps across the moss, lingers, thins and is gone.
## Touching the mist while it is thick costs Gill one health, at most once per release.
##
## Timing is its own (each bloom has its own rhythm from where it grows; never the gameplay random
## sequence). Only the player's ball, within ACTIVE_M, ever runs it. Placed by SporeBlooms.

const WARN_S := 2.4
const IDLE_MIN_S := 11.0
const IDLE_MAX_S := 19.0
## The mist: puffs, how far it creeps and for how long it is thick, then how long it takes to thin.
const PUFFS := 22
const SPREAD_M := 4.6
const THICK_S := 3.6
const FADE_S := 2.2
## Hurts only this low over the moss (m) and inside this share of its present reach.
const HURT_H := 1.7
const HURT_REACH := 0.85
const ACTIVE_M := 70.0
const MIST_COL := Color(0.7, 0.74, 0.16, 0.38)

var ball: MossBall
var dir := Vector3.UP
var up := Vector3.UP
var _fr: Basis
var _rng := RandomNumberGenerator.new()
## "idle", "warn", "mist"
var state := "idle"
var t := 0.0
var _next := 10.0
var _hurt_this := false
var _pods: Array[MeshInstance3D] = []
var _pod_mat: StandardMaterial3D
var _mist: MultiMeshInstance3D
var _puff_dir: Array[Vector3] = []
var _puff_speed: Array[float] = []
var _puff_h: Array[float] = []
var _puff_size: Array[float] = []
## For tests: releases so far and hurts dealt.
var releases := 0
var hurts := 0


func setup(p_ball: MossBall, p_dir: Vector3, seed_v: int) -> void:
	ball = p_ball
	dir = p_dir.normalized()
	up = dir
	_rng.seed = seed_v
	_next = _rng.randf_range(2.0, IDLE_MAX_S)
	_fr = MossBall.frame_at(up, _rng.randf() * 360.0)


func _ready() -> void:
	name = "SporeBloom"
	global_position = ball.surface_point(dir, 0.0)
	global_basis = Basis(_fr.x, up, _fr.z)
	# The unhealthy patch it grows from: a dull, mottled stain on the moss.
	var stain := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(5.0, 5.0)
	stain.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/spore_stain.gdshader")
	stain.material_override = sm
	stain.position = Vector3(0, 0.04, 0)
	stain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stain)
	# The growth: a few swollen, bumpy pods on short stalks.
	_pod_mat = StandardMaterial3D.new()
	_pod_mat.albedo_color = Color(0.4, 0.38, 0.15)
	_pod_mat.roughness = 0.75
	_pod_mat.emission_enabled = true
	_pod_mat.emission = Color(0.9, 0.85, 0.2)
	_pod_mat.emission_energy_multiplier = 0.0
	var stalk_mat := StandardMaterial3D.new()
	stalk_mat.albedo_color = Color(0.3, 0.27, 0.14)
	stalk_mat.roughness = 0.9
	var n_pods := 4 + (_rng.randi() % 2)
	for i in n_pods:
		var a := TAU * i / n_pods + _rng.randf_range(-0.4, 0.4)
		var off := Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.2, 0.55)
		var h := _rng.randf_range(0.35, 0.85)
		var stalk := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.07
		cm.bottom_radius = 0.13
		cm.height = h
		stalk.mesh = cm
		stalk.material_override = stalk_mat
		stalk.position = off + Vector3(0, h * 0.5, 0)
		add_child(stalk)
		var pod := MeshInstance3D.new()
		var sp := SphereMesh.new()
		var r := _rng.randf_range(0.3, 0.48)
		sp.radius = r
		sp.height = r * 2.2
		sp.radial_segments = 12
		sp.rings = 8
		pod.mesh = sp
		pod.material_override = _pod_mat
		pod.position = off + Vector3(0, h + r * 0.8, 0)
		pod.set_meta("base", pod.position)
		add_child(pod)
		_pods.append(pod)
	# The mist: one pooled set of soft billboards.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	mm.mesh = q
	mm.instance_count = PUFFS
	mm.custom_aabb = AABB(Vector3(-10, -3, -10), Vector3(20, 8, 20))
	_mist = MultiMeshInstance3D.new()
	_mist.multimesh = mm
	var mmat := ShaderMaterial.new()
	mmat.shader = preload("res://shaders/spore_mist.gdshader")
	_mist.material_override = mmat
	_mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mist.visible = false
	add_child(_mist)
	for i in PUFFS:
		_puff_dir.append(Vector3.ZERO)
		_puff_speed.append(0.0)
		_puff_h.append(0.0)
		_puff_size.append(0.0)


## Where the mist reaches now (m from the bloom), 0 when there is none.
func reach() -> float:
	if state != "mist":
		return 0.0
	return minf(SPREAD_M, 0.8 + t * 2.1) * (1.0 + 0.15 * clampf((t - THICK_S) / FADE_S, 0.0, 1.0))


## Whether the mist is thick enough to hurt now.
func thick() -> bool:
	return state == "mist" and t >= 0.25 and t < THICK_S


## Whether `pos` is in the thick mist: inside its reach, low over the moss.
func in_mist(pos: Vector3) -> bool:
	if not thick():
		return false
	var rel := pos - global_position
	var h := rel.dot(up)
	var flat := (rel - up * h).length()
	return flat < reach() * HURT_REACH and h < HURT_H and h > -1.0


## One step (SporeBlooms calls it for the blooms near him). `gill` may be null.
func step(dt: float, gill: Axolotl) -> void:
	t += dt
	match state:
		"idle":
			_pod_mat.emission_energy_multiplier = maxf(0.0, _pod_mat.emission_energy_multiplier - dt * 0.1)
			for p in _pods:
				p.scale = Vector3.ONE * (1.0 + sin(t * 0.9 + p.position.x * 9.0) * 0.03)
			if t >= _next:
				_enter("warn")
				Sfx.play("spore_hiss", global_position, -6.0, 0.08)
		"warn":
			# Swelling, trembling, glowing: an observant player sees it coming.
			var k := clampf(t / WARN_S, 0.0, 1.0)
			_pod_mat.emission_energy_multiplier = (0.4 + 0.6 * sin(t * 9.0) * 0.5 + 0.5) * k * 1.6
			for p in _pods:
				var tremble := Vector3(sin(t * 31.0 + p.position.z * 7.0), 0, cos(t * 27.0)) * 0.02 * k
				p.scale = Vector3.ONE * (1.0 + 0.45 * k * k)
				p.position = (p.get_meta("base") as Vector3) + tremble
			if _rng.randf() < dt * 6.0 * k and WaterFX.inst != null:
				WaterFX.inst.sparkle(_pods[_rng.randi() % _pods.size()].global_position, Color(0.95, 0.9, 0.3, 0.7), 2, 0.4, 0.04, 0.8)
			if t >= WARN_S:
				_release()
		"mist":
			_update_mist()
			if gill != null and not _hurt_this and in_mist(gill.global_position):
				_hurt_this = true
				hurts += 1
				gill.take_damage(1, global_position)
			if t >= THICK_S + FADE_S:
				_mist.visible = false
				_enter("idle")
				_next = _rng.randf_range(IDLE_MIN_S, IDLE_MAX_S)


func _enter(s: String) -> void:
	state = s
	t = 0.0


func _release() -> void:
	releases += 1
	_hurt_this = false
	_pod_mat.emission_energy_multiplier = 0.15
	for p in _pods:
		p.scale = Vector3.ONE * 0.8
		p.position = p.get_meta("base")
	Sfx.play("spore_puff", global_position, -4.0, 0.1)
	for i in PUFFS:
		var a := TAU * i / PUFFS + _rng.randf_range(-0.3, 0.3)
		_puff_dir[i] = Vector3(cos(a), 0, sin(a))
		_puff_speed[i] = _rng.randf_range(0.55, 1.0)
		_puff_h[i] = _rng.randf_range(0.15, 0.85)
		_puff_size[i] = _rng.randf_range(0.8, 1.3)
	_mist.visible = true
	_enter("mist")
	_update_mist()


func _update_mist() -> void:
	var mm := _mist.multimesh
	var r := reach()
	var fade := 1.0 - clampf((t - THICK_S) / FADE_S, 0.0, 1.0)
	var grow := clampf(t / 0.3, 0.0, 1.0)
	for i in PUFFS:
		# Creeps out along the moss, curling a little, hugging the surface.
		var d := _puff_dir[i].rotated(Vector3.UP, sin(t * 0.7 + i) * 0.25)
		var dist := r * _puff_speed[i]
		var lp := d * dist + Vector3(0, _puff_h[i] * (0.6 + 0.4 * sin(t * 1.3 + i * 1.7)), 0)
		# (The ball curves away under it: keep each puff at its height over the moss.)
		var wp := to_global(lp)
		var gd := (wp - ball.global_position).normalized()
		wp = ball.surface_point(gd, lp.y)
		var size := _puff_size[i] * (0.7 + dist * 0.35) * grow
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * size), to_local(wp)))
		mm.set_instance_color(i, Color(MIST_COL.r, MIST_COL.g, MIST_COL.b, MIST_COL.a * fade * grow))
