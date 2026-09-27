class_name AxolotlModel
extends Node3D
## Procedural axolotl: built from primitives and animated entirely in code.
## Local space: -Z forward, +Y up, origin on the ground under the body centre.

const BODY_COLOR := Color(0.96, 0.7, 0.76)
const BELLY_COLOR := Color(1.0, 0.84, 0.86)
const GILL_COLOR := Color(0.9, 0.26, 0.42)
const FROND_ON := Color(0.35, 1.0, 0.9)
const FROND_OFF := Color(0.16, 0.3, 0.32)
const FROND_DORMANT := Color(0.55, 0.47, 0.5)

var rig: Node3D
var body_root: Node3D
var head: Node3D
var eye_l: Node3D
var eye_r: Node3D
var mouth: MeshInstance3D
var gills: Array[Node3D] = []      # 6 gill pivots (3 left, 3 right)
var legs: Array[Node3D] = []       # FL, FR, BL, BR hip pivots
var tail: Array[Node3D] = []
var fronds: Array[Node3D] = []
var frond_mats: Array[StandardMaterial3D] = []
var swipe_fx: MeshInstance3D
var _swipe_mat: ShaderMaterial

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

# Health display.
var health := 3
var max_health := 3
var _frond_flash := 0.0
var _fall_flicker := 0.0
var _frond_grow: Array[float] = [1, 1, 1, 0, 0, 0]

var _t := 0.0
var _gait := 0.0
var _blink := 2.0


func _ready() -> void:
	_build()


func _m(c: Color, rough := 0.55, rim := 0.35) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if rim > 0.0:
		m.rim_enabled = true
		m.rim = rim
		m.rim_tint = 0.4
	return m


func _sphere(r: float, mat: Material, parent: Node3D, pos := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	mi.mesh = s
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _capsule(r: float, h: float, mat: Material, parent: Node3D, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 10
	c.rings = 3
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _build() -> void:
	var body_mat := _m(BODY_COLOR)
	var belly_mat := _m(BELLY_COLOR, 0.6, 0.2)
	var gill_mat := _m(GILL_COLOR, 0.5, 0.5)
	gill_mat.emission_enabled = true
	gill_mat.emission = GILL_COLOR
	gill_mat.emission_energy_multiplier = 0.25
	var eye_mat := _m(Color(0.04, 0.03, 0.05), 0.15, 0.0)
	var shine_mat := _m(Color.WHITE, 0.2, 0.0)
	shine_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mouth_mat := _m(Color(0.55, 0.22, 0.3), 0.6, 0.0)
	var blush_mat := _m(Color(1.0, 0.55, 0.62), 0.7, 0.0)

	rig = Node3D.new()
	add_child(rig)
	body_root = Node3D.new()
	body_root.position = Vector3(0, 0.2, 0)
	rig.add_child(body_root)

	# Torso + belly.
	var torso := _capsule(0.15, 0.66, body_mat, body_root, Vector3.ZERO, Vector3(PI / 2, 0, 0))
	torso.scale = Vector3(1.12, 1.0, 0.86)
	_capsule(0.12, 0.5, belly_mat, body_root, Vector3(0, -0.04, 0.02), Vector3(PI / 2, 0, 0)).scale = Vector3(1.15, 1.0, 0.7)

	# Head.
	head = Node3D.new()
	head.position = Vector3(0, 0.03, -0.33)
	body_root.add_child(head)
	_sphere(0.2, body_mat, head, Vector3(0, 0, -0.06), Vector3(1.32, 0.78, 1.0))
	_sphere(0.05, blush_mat, head, Vector3(0.16, -0.04, -0.17), Vector3(1, 0.6, 0.6))
	_sphere(0.05, blush_mat, head, Vector3(-0.16, -0.04, -0.17), Vector3(1, 0.6, 0.6))
	eye_l = Node3D.new()
	eye_l.position = Vector3(-0.17, 0.065, -0.14)
	head.add_child(eye_l)
	eye_r = Node3D.new()
	eye_r.position = Vector3(0.17, 0.065, -0.14)
	head.add_child(eye_r)
	for e in [eye_l, eye_r]:
		_sphere(0.036, eye_mat, e)
		_sphere(0.012, shine_mat, e, Vector3(0.0, 0.016, -0.028))
	mouth = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.1
	tm.outer_radius = 0.115
	tm.rings = 16
	tm.ring_segments = 6
	mouth.mesh = tm
	mouth.material_override = mouth_mat
	mouth.position = Vector3(0, -0.035, -0.12)
	mouth.scale = Vector3(1.05, 0.35, 0.95)
	head.add_child(mouth)

	# External gills: three feathery stalks per side.
	for side in [-1.0, 1.0]:
		for k in 3:
			var g := Node3D.new()
			g.position = Vector3(side * 0.2, 0.1 - k * 0.055, 0.02 + k * 0.02)
			g.rotation = Vector3(0, side * (0.9 + k * 0.25), side * (0.6 - k * 0.45))
			head.add_child(g)
			var stalk_len := 0.2 - k * 0.02
			# Stalk + feathery filaments merged into one mesh (one draw call per gill).
			var parts := [[MeshLib.capsule(0.018, stalk_len), Transform3D(Basis.from_euler(Vector3(0, 0, PI / 2)), Vector3(side * stalk_len * 0.5, 0, 0))]]
			for f in 5:
				var fx: float = side * (0.04 + f * 0.035)
				parts.append([MeshLib.capsule(0.009, 0.07), Transform3D(Basis.from_euler(Vector3(0.3, 0, 0)), Vector3(fx, 0.022, 0))])
				parts.append([MeshLib.capsule(0.009, 0.07), Transform3D(Basis.from_euler(Vector3(-0.3, 0, 0)), Vector3(fx, -0.022, 0))])
			var gm := MeshInstance3D.new()
			gm.mesh = MeshLib.merge(parts)
			gm.material_override = gill_mat
			g.add_child(gm)
			gills.append(g)

	# Legs: little splayed limbs with four-toed hands.
	var hip_pos := [Vector3(-0.13, -0.05, -0.17), Vector3(0.13, -0.05, -0.17), Vector3(-0.13, -0.05, 0.19), Vector3(0.13, -0.05, 0.19)]
	for i in 4:
		var hip := Node3D.new()
		hip.position = hip_pos[i]
		body_root.add_child(hip)
		var side := -1.0 if i % 2 == 0 else 1.0
		var upper := Node3D.new()
		hip.add_child(upper)
		_capsule(0.032, 0.15, body_mat, upper, Vector3(side * 0.06, -0.05, 0), Vector3(0, 0, side * 0.95))
		var hand := Node3D.new()
		hand.position = Vector3(side * 0.11, -0.12, 0)
		upper.add_child(hand)
		var hparts := [[MeshLib.sphere(0.035, 8, 4), Transform3D(Basis().scaled(Vector3(1.2, 0.6, 1.2)), Vector3.ZERO)]]
		for t in 4:
			var a := -0.7 + t * 0.47
			hparts.append([MeshLib.capsule(0.01, 0.05), Transform3D(Basis.from_euler(Vector3(PI / 2, -a, 0)), Vector3(sin(a) * 0.035, -0.004, -cos(a) * 0.035))])
		var hm := MeshInstance3D.new()
		hm.mesh = MeshLib.merge(hparts)
		hm.material_override = body_mat
		hand.add_child(hm)
		legs.append(hip)

	# Tail: segment chain, flattened with a fin.
	var parent: Node3D = body_root
	var z := 0.3
	for i in 6:
		var seg := Node3D.new()
		seg.position = Vector3(0, 0.0 if i > 0 else 0.0, z if i == 0 else 0.13)
		parent.add_child(seg)
		var w := lerpf(0.1, 0.025, i / 5.0)
		var h := lerpf(0.13, 0.05, i / 5.0)
		_sphere(0.1, body_mat, seg, Vector3(0, 0, 0.065), Vector3(w * 10.0 * 0.9, h * 10.0 * 0.85, 0.85))
		_sphere(0.1, _fin_mat(), seg, Vector3(0, h * 0.6, 0.065), Vector3(0.12, h * 7.0, 0.85))
		_sphere(0.1, _fin_mat(), seg, Vector3(0, -h * 0.45, 0.065), Vector3(0.1, h * 4.5, 0.8))
		tail.append(seg)
		parent = seg

	# Six bioluminescent dorsal health fronds along the upper back.
	for i in 6:
		var f := Node3D.new()
		f.position = Vector3(0, 0.13 - absf(i - 2.5) * 0.004, -0.2 + i * 0.095)
		body_root.add_child(f)
		var fm := StandardMaterial3D.new()
		fm.albedo_color = FROND_ON
		fm.emission_enabled = true
		fm.emission = FROND_ON
		fm.emission_energy_multiplier = 2.0
		fm.roughness = 0.4
		frond_mats.append(fm)
		var leaf := _sphere(0.1, fm, f, Vector3(0, 0.06, 0.012), Vector3(0.26, 0.7, 0.42))
		leaf.rotation = Vector3(-0.35, 0, 0)
		_sphere(0.02, fm, f, Vector3(0, 0.0, 0), Vector3(1, 0.8, 1))
		fronds.append(f)

	# Water arc shown during the tail swipe (180-degree sweep behind/beside).
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


func _fin_mat() -> StandardMaterial3D:
	var m := _m(Color(1.0, 0.8, 0.84), 0.5, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	return m


## Half-annulus behind the body (+Z side), UV.x = angle 0..1, UV.y = radial.
func _arc_mesh(r_out: float, r_in: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 20
	for i in n:
		var a0 := -PI / 2 + PI * i / n
		var a1 := -PI / 2 + PI * (i + 1) / n
		var p := [Vector3(sin(a0) * r_in, 0, cos(a0) * r_in), Vector3(sin(a0) * r_out, 0, cos(a0) * r_out),
				Vector3(sin(a1) * r_out, 0, cos(a1) * r_out), Vector3(sin(a1) * r_in, 0, cos(a1) * r_in)]
		var uv := [Vector2(float(i) / n, 0), Vector2(float(i) / n, 1), Vector2(float(i + 1) / n, 1), Vector2(float(i + 1) / n, 0)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[k])
			st.add_vertex(p[k])
	return st.commit()


# --- Health fronds -----------------------------------------------------------------------

func set_health(h: int, mx: int, flash := true) -> void:
	health = h
	max_health = mx
	if flash:
		_frond_flash = 0.6


func fall_flicker() -> void:
	_fall_flicker = 1.2


func _update_fronds(dt: float) -> void:
	_frond_flash = maxf(0.0, _frond_flash - dt)
	_fall_flicker = maxf(0.0, _fall_flicker - dt)
	for i in 6:
		var target_grow := 1.0 if i < max_health else 0.45
		_frond_grow[i] = move_toward(_frond_grow[i], target_grow, dt * 1.5)
		var f := fronds[i]
		var g := _frond_grow[i]
		var sway := sin(_t * 2.2 + i * 0.7) * 0.12 - speed * 0.25
		f.rotation = Vector3(sway - (1.0 - g) * 0.6, 0, 0)
		f.scale = Vector3.ONE * lerpf(0.55, 1.0, g) * (1.0 - dissolve)
		var m := frond_mats[i]
		if i < health:
			var e := 1.8 + sin(_t * 2.0 + i) * 0.25
			if health == 1:
				# Irregular heartbeat-like pulse on the final segment.
				var p := pow(maxf(0.0, sin(_t * 5.3) * sin(_t * 2.1 + 1.3)), 3.0)
				e = 0.9 + p * 3.5 + (0.4 if fmod(_t, 1.7) < 0.08 else 0.0)
			if _frond_flash > 0.0:
				e += _frond_flash * 5.0
			if _fall_flicker > 0.0 and i == health - 1:
				e *= 0.2 + 1.8 * float(int(_t * 24.0) % 2)
			m.albedo_color = FROND_ON
			m.emission = FROND_ON
			m.emission_energy_multiplier = e
		elif i < max_health:
			m.albedo_color = FROND_OFF
			m.emission = FROND_ON
			m.emission_energy_multiplier = 0.05
		else:
			m.albedo_color = FROND_DORMANT
			m.emission = FROND_DORMANT
			m.emission_energy_multiplier = 0.0


# --- Animation ---------------------------------------------------------------------------

func play_land(variant: int, strength: float) -> void:
	land_variant = variant
	land_strength = strength
	land_t = 0.0


func _process(dt: float) -> void:
	_t += dt
	_gait += dt * (2.0 + speed * 11.0) * (1.0 if grounded else 0.0)
	_advance_timers(dt)
	_update_fronds(dt)
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
	var tail_amp := 0.12 + 0.35 * s
	var tail_freq := 3.0 + 7.0 * s
	var tail_base := 0.0
	var gill_back := s * 0.5
	var gill_flare := 0.0
	var gill_flap := 0.12
	var leg_mode := 0   # 0 walk, 1 tuck (air), 2 spread (brace/surf)

	# Idle breathing / walk bob.
	rig_pos.y = sin(_gait * 2.0) * 0.012 * s + sin(_t * 1.6) * 0.006
	rig_rot.y = sin(_gait) * 0.08 * s

	if not grounded:
		leg_mode = 1
		rig_rot.x = clampf(vup * 0.04, -0.45, 0.35)
		rig_scale = Vector3(0.95, 0.95, 1.1)
		gill_back = maxf(gill_back, 0.5)
		tail_amp = 0.25
		tail_freq = 6.0
	if burst_t >= 0.0:
		var k := sin(burst_t * PI)
		tail_amp = 0.9 * k + 0.2
		tail_freq = 16.0
		rig_scale = Vector3(0.9, 0.9, 1.0 + 0.25 * k)
		gill_back = 1.0
		mouth_open = 0.7
	if swipe_t >= 0.0:
		# Body twists while the tail sweeps across the rear 180 degrees.
		var k := swipe_t
		rig_rot.y += sin(k * PI) * 0.55 * swipe_side
		tail_base = lerpf(-1.4, 1.4, smoothstep(0.0, 1.0, k)) * swipe_side
		tail_amp = 0.05
	if lunge_t >= 0.0:
		var k := sin(clampf(lunge_t, 0.0, 1.0) * PI)
		rig_pos.z -= 0.18 * k
		rig_scale = Vector3(0.92, 0.92, 1.0 + 0.3 * k)
		head_rot.x = -0.2 * k
		mouth_open = 0.35 + 1.4 * k
		gill_back = 1.0
		leg_mode = 1
	if brace > 0.0:
		leg_mode = 2
		gill_back = 1.0 + brace * 0.3
		eye_scale = Vector3.ONE * (1.0 + 0.4 * brace)
		rig_scale = Vector3(1.08, 0.85, 0.98)
		rig_rot.x = 0.25 * brace
		tail_base = 0.0
		tail_amp = 0.08
		mouth_open = 0.9
	if surf > 0.0:
		leg_mode = 2
		rig_rot.z = surf_bank
		gill_back = 1.3
		mouth_open = 1.1
		eye_scale = Vector3(1.0, 0.55, 1.0)   # happy squint
		tail_amp = 0.3
		tail_freq = 5.0
		tail_base = -surf_bank * 0.6
	if hurt_t >= 0.0:
		var k := sin(hurt_t * PI)
		rig_rot.x -= 0.35 * k
		rig_rot.z += 0.25 * k
		rig_scale *= Vector3(1.1, 0.8, 0.95).lerp(Vector3.ONE, 1.0 - k)
		eye_scale = Vector3(1.0, 0.15, 1.0)
		mouth_open = 0.1
	if shake_t >= 0.0:
		var k := 1.0 - shake_t
		head_rot.y += sin(shake_t * 38.0) * 0.45 * k
		gill_flap = 0.6 * k
	if happy_t >= 0.0:
		var k := sin(happy_t * PI)
		rig_pos.y += absf(sin(happy_t * PI * 3.0)) * 0.08 * k
		rig_rot.z += sin(happy_t * 25.0) * 0.12 * k
		gill_flap = maxf(gill_flap, 0.5 * k)
		mouth_open = 0.35 + 0.7 * k
		eye_scale = Vector3(1.0, lerpf(1.0, 0.5, k), 1.0)
	if perk_t >= 0.0:
		var k := sin(perk_t * PI)
		head_rot.x -= 0.25 * k
		gill_flare = 0.6 * k
		eye_scale = eye_scale * (1.0 + 0.2 * k)
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

	# Look toward interesting things (clamped).
	if has_look and land_t < 0.0 and swipe_t < 0.0:
		var local := to_local(look_target)
		var yaw := clampf(atan2(-local.x, -local.z), -0.7, 0.7)
		head_rot.y += yaw
	if _blink < 0.0:
		eye_scale.y *= 0.1

	rig.position = rig.position.lerp(rig_pos, minf(1.0, dt * 18.0))
	rig.rotation = rig.rotation.lerp(rig_rot, minf(1.0, dt * 14.0))
	rig.scale = rig.scale.lerp(rig_scale * (1.0 - dissolve), minf(1.0, dt * 16.0))
	head.rotation = head.rotation.lerp(head_rot, minf(1.0, dt * 12.0))
	eye_l.scale = eye_l.scale.lerp(eye_scale * eye_l_scale, minf(1.0, dt * 20.0))
	eye_r.scale = eye_r.scale.lerp(eye_scale, minf(1.0, dt * 20.0))
	mouth.scale = mouth.scale.lerp(Vector3(1.05, 0.2 + mouth_open * 0.45, 0.95), minf(1.0, dt * 14.0))

	# Tail undulation (travelling wave).
	for i in tail.size():
		var amp := tail_amp * (0.4 + i * 0.18)
		var yaw := sin(_t * tail_freq - i * 0.75) * amp
		if i == 0:
			yaw += tail_base
		elif swipe_t >= 0.0:
			yaw += tail_base * 0.12
		var pitch := 0.0
		if brace > 0.0:
			pitch = -0.12 * brace
		tail[i].rotation = tail[i].rotation.lerp(Vector3(pitch, yaw, 0), minf(1.0, dt * 20.0))

	# Gills: sway with water, pin back with speed, flare when perked.
	for i in gills.size():
		var side := -1.0 if i < 3 else 1.0
		var k := i % 3
		var base := Vector3(0, side * (0.9 + k * 0.25), side * (0.6 - k * 0.45))
		var sway := sin(_t * 2.4 + i * 1.1) * gill_flap + sin(_t * 17.0 + i) * gill_flap * 0.4 * float(gill_flap > 0.3)
		var back := clampf(gill_back, 0.0, 1.4)
		var rot := base + Vector3(0, side * (back * 0.9 - gill_flare * 0.3) + sway, side * (sway * 0.5 + gill_flare * 0.4 - back * 0.25))
		gills[i].rotation = gills[i].rotation.lerp(rot, minf(1.0, dt * 12.0))

	# Legs: diagonal-pair scuttle, tucked in air, spread when bracing/surfing.
	for i in legs.size():
		var side := -1.0 if i % 2 == 0 else 1.0
		var front := i < 2
		var phase := _gait + (0.0 if (i == 0 or i == 3) else PI)
		var rot := Vector3.ZERO
		match leg_mode:
			0:
				var swing := sin(phase) * 0.7 * minf(s * 1.5, 1.0)
				var lift := maxf(0.0, cos(phase)) * 0.45 * minf(s * 2.0, 1.0)
				rot = Vector3(0, swing * side * (1.0 if front else -1.0) * -1.0, lift * side)
			1:
				rot = Vector3(0, side * (0.9 if front else -0.9) * -1.0 * (1.0 if front else 1.0), side * 0.2)
				if front:
					rot = Vector3(0, -side * 1.0, side * 0.25)
				else:
					rot = Vector3(0, side * 1.1, side * 0.25)
			2:
				rot = Vector3(0, side * (0.4 if front else -0.4), side * 0.55 + sin(_t * 8.0 + i) * 0.1)
		if land_t >= 0.0 and land_variant == 0 and i == 1:
			rot = _land_pose["fist"]
		legs[i].rotation = legs[i].rotation.lerp(rot, minf(1.0, dt * 16.0))

	# Swipe water arc.
	if swipe_t >= 0.0:
		swipe_fx.visible = true
		_swipe_mat.set_shader_parameter("progress", swipe_t)
		_swipe_mat.set_shader_parameter("side", swipe_side)
	else:
		swipe_fx.visible = false


var _land_pose := {}


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
