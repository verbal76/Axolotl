class_name Mote
extends Node3D
## Regeneration Mote: a tiny living bioluminescent spore-organism tied to one damaged
## patch. Wanders just above the moss, is nudged by water, must be caught with the lunge,
## and when caught dives into the moss (its light following it down) to restore the patch.

var ball: MossBall
var zone_id := ""
var anchor := Vector3.ZERO       # ground point it belongs to
var anchor_up := Vector3.UP
var wander := 2.2
var h_hint := 0.0
var state := "init"              # init wander captured done
var vel := Vector3.ZERO
var intensity := 1.0
var _target := Vector3.ZERO
var _retarget := 0.0
var _t := 0.0
var _dive_from := Vector3.ZERO
var _dive_to := Vector3.ZERO
var _core: MeshInstance3D
var _halo: MeshInstance3D
var _cilia: Node3D
var _dir := Vector3.UP


func setup(p_ball: MossBall, p_zone: String, dir: Vector3, h := 0.0, p_wander := 2.2) -> void:
	ball = p_ball
	zone_id = p_zone
	_dir = dir.normalized()
	h_hint = h
	wander = p_wander
	ball.register_event(zone_id)


func _ready() -> void:
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.75, 1.0, 0.82)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.5, 1.0, 0.7)
	core_mat.emission_energy_multiplier = 4.0
	_core = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.06
	s.height = 0.1
	s.radial_segments = 10
	s.rings = 5
	_core.mesh = s
	_core.material_override = core_mat
	add_child(_core)
	# Soft glow (not a marker ring): additive billboard that fades with distance.
	_halo = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	_halo.mesh = q
	var hm := ShaderMaterial.new()
	hm.shader = preload("res://shaders/glow_billboard.gdshader")
	_halo.material_override = hm
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)
	# Wispy filaments / spore strands so it reads as a living organism.
	_cilia = Node3D.new()
	add_child(_cilia)
	var fil_mat := StandardMaterial3D.new()
	fil_mat.albedo_color = Color(0.6, 1.0, 0.75)
	fil_mat.emission_enabled = true
	fil_mat.emission = Color(0.45, 0.95, 0.65)
	fil_mat.emission_energy_multiplier = 2.0
	for i in 7:
		var c := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.008
		cm.height = randf_range(0.12, 0.22)
		cm.radial_segments = 4
		cm.rings = 1
		c.mesh = cm
		c.material_override = fil_mat
		var d := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized()
		c.position = d * cm.height * 0.5
		c.basis = Basis(Quaternion(Vector3.UP, d))
		_cilia.add_child(c)
		var bud := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = 0.018
		bs.height = 0.036
		bs.radial_segments = 6
		bs.rings = 3
		bud.mesh = bs
		bud.material_override = core_mat
		bud.position = d * cm.height
		_cilia.add_child(bud)


func is_available() -> bool:
	return state == "wander"


func light_intensity() -> float:
	return intensity


func _physics_process(dt: float) -> void:
	if state == "done":
		return
	if state == "init":
		var top := ball.surface_point(_dir, h_hint + 3.0)
		var q := PhysicsRayQueryParameters3D.create(top, ball.global_position, 1 | 2)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		anchor = hit.position if not hit.is_empty() else ball.surface_point(_dir)
		anchor_up = ball.up_at(anchor)
		global_position = anchor + anchor_up * 0.6
		_target = global_position
		state = "wander"
		return
	_t += dt
	if Game.inst.player.ball != ball:
		return
	match state:
		"wander":
			_update_wander(dt)
		"captured":
			var k := minf(1.0, _t / 0.8)
			global_position = _dive_from.lerp(_dive_to, k * k)
			intensity = 1.0 + (1.0 - k) * 1.5
			scale = Vector3.ONE * (1.0 - k * 0.7)
			if k >= 1.0:
				state = "done"
				intensity = 0.0
				visible = false
				Game.inst.mote_restored(self)
	_cilia.rotation += Vector3(0.7, 1.3, 0.4) * dt
	var pulse := 0.85 + 0.15 * sin(_t * 3.1) + 0.05 * sin(_t * 11.0)
	_core.scale = Vector3.ONE * pulse
	if state == "wander":
		intensity = pulse


func _update_wander(dt: float) -> void:
	var up := ball.up_at(global_position)
	_retarget -= dt
	if _retarget <= 0.0 or global_position.distance_to(_target) < 0.25:
		_retarget = randf_range(1.2, 3.0)
		var b := MossBall.frame_at(anchor_up, randf() * 360.0)
		var off := (b.x * (randf() * 2.0 - 1.0) + b.z * (randf() * 2.0 - 1.0)) * wander
		_target = anchor + off + anchor_up * randf_range(0.35, 0.95)
	var steer := (_target - global_position).limit_length(1.0) * 1.4
	vel += steer * dt
	# Tiny currents and axolotl-made water movement push it around.
	vel += WaterFX.inst.push_at(global_position) * 3.5 * dt
	vel += ball.current_at(global_position) * 0.08 * dt
	vel += Vector3(sin(_t * 1.7), sin(_t * 2.3 + 1.0), cos(_t * 1.3)) * 0.25 * dt
	# Leash to its patch; keep hovering above the moss.
	var from_anchor := global_position - anchor
	var lateral := from_anchor - anchor_up * from_anchor.dot(anchor_up)
	if lateral.length() > wander * 1.6:
		vel -= lateral.normalized() * (lateral.length() - wander * 1.6) * 3.0 * dt
	var height := from_anchor.dot(anchor_up)
	if height < 0.3:
		vel += anchor_up * (0.3 - height) * 6.0 * dt
	elif height > 1.4:
		vel -= anchor_up * (height - 1.4) * 3.0 * dt
	vel = vel.limit_length(3.5)
	vel *= 1.0 - 0.9 * dt
	global_position += vel * dt


## Water pressure from a near-miss lunge: pushed like a floating object in a pool.
func push(v: Vector3) -> void:
	if state == "wander":
		vel += v


func capture() -> void:
	if state != "wander":
		return
	state = "captured"
	_t = 0.0
	_dive_from = global_position
	var up := ball.up_at(global_position)
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position - up * 4.0, 1 | 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	_dive_to = (hit.position if not hit.is_empty() else anchor) - up * 0.25
