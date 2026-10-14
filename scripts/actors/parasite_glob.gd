class_name ParasiteGlob
extends Node3D
## A spitter parasite's glob (Expansion 6, docs/ECOSYSTEM.md): a slow, glowing blob of stolen
## vitality, easy to see against the healed and the murky tank alike. It flies straight at where
## the axolotl was when it was spat (no homing: a sidestep dodges it), splats on rock, moss or
## plants, and hurts him once on contact. A well-timed tail swipe bats it back toward the spitter,
## where it hurts the spitter instead.

const SPEED := 5.0
const RADIUS := 0.2
const LIFE := 3.2
const HIT_R := 0.38

## Globs in flight (few: one per spitter at a time).
static var live: Array[ParasiteGlob] = []

var ball: MossBall
var spitter: Parasite
var vel := Vector3.ZERO
var reflected := false
var _t := 0.0
var _trail_t := 0.0
var _done := false


## Launched from `from` toward `target` (both world positions).
func launch(p_spitter: Parasite, p_ball: MossBall, from: Vector3, target: Vector3) -> void:
	spitter = p_spitter
	ball = p_ball
	vel = (target - from).normalized() * SPEED
	p_ball.add_child(self)
	global_position = from
	live.append(self)


## Owner, 2026-10-07: a fluid, squishy blob of slime, not a glowing ball (shaders/glob.gdshader):
## a teardrop along its flight that wobbles and pulses, with two small droplets trailing it. Batted
## by the tail it squashes and flies back; on anything it hits it splats into a few droplets and a
## brief flattened splash. Cheap: one low sphere and two tiny ones, one material per glob.
static var _blob_mesh: SphereMesh
var _mat: ShaderMaterial
var _drops: Array[MeshInstance3D] = []
var _squash := 0.0


func _ready() -> void:
	if _blob_mesh == null:
		_blob_mesh = SphereMesh.new()
		_blob_mesh.radius = 1.0
		_blob_mesh.height = 2.0
		_blob_mesh.radial_segments = 20
		_blob_mesh.rings = 10
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/glob.gdshader")
	_mat.set_shader_parameter("seed", WaterFX._fx_rng.randf() * 10.0)
	var core := MeshInstance3D.new()
	core.mesh = _blob_mesh
	core.scale = Vector3.ONE * RADIUS * 1.25
	core.material_override = _mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	for k in 2:
		var d := MeshInstance3D.new()
		d.mesh = _blob_mesh
		d.scale = Vector3.ONE * RADIUS * (0.38 - k * 0.12)
		d.material_override = _mat
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(d)
		_drops.append(d)


## Faces along its flight (the shader draws the teardrop along -Z), its droplets trailing and weaving.
func _shape(dt: float) -> void:
	if vel.length() > 0.01:
		var f := vel.normalized()
		var upv := Vector3.UP if absf(f.y) < 0.95 else Vector3.RIGHT
		global_basis = Basis.looking_at(f, upv)
	_squash = maxf(0.0, _squash - dt * 4.0)
	_mat.set_shader_parameter("squash", _squash)
	for k in _drops.size():
		var lag := RADIUS * (2.2 + k * 1.3)
		_drops[k].position = Vector3(sin(_t * (9.0 + k * 3.0) + k) * 0.05, cos(_t * (7.0 + k * 2.0)) * 0.05, lag)


func _physics_process(dt: float) -> void:
	if _done or Game.paused_for_aquarium():
		return
	_t += dt
	var from := global_position
	var to := from + vel * dt
	# Rock, moss and plants stop it (it never passes through terrain).
	var q := PhysicsRayQueryParameters3D.create(from, to + vel.normalized() * RADIUS, 1 | 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position = hit["position"]
		_splat()
		return
	var pl: Axolotl = Game.inst.player if Game.inst else null
	if not reflected:
		if pl != null and pl.ball == ball and pl.state == "normal" and _seg_dist(pl.body_center(), from, to) < HIT_R + RADIUS:
			pl.take_damage(1, from)
			global_position = to
			_splat()
			return
	else:
		for par in ball.hostiles():
			if par.is_alive() and par.closest_body_point(to).distance_to(to) < RADIUS + par.body_extent() + 0.15:
				par.hit(1, from)
				global_position = to
				_splat()
				return
	global_position = to
	_shape(dt)
	_trail_t -= dt
	if _trail_t <= 0.0:
		_trail_t = 0.12
		WaterFX.inst.sparkle(to + vel.normalized() * RADIUS * 2.5, Color(0.7, 1.0, 0.3, 0.6), 1, 0.25, 0.04, 0.4)
	if _t > LIFE:
		_splat()


## Batted back by the tail: toward its spitter if it is still alive, otherwise straight back.
func deflect(p: Axolotl) -> void:
	if reflected or _done:
		return
	reflected = true
	var dir := -vel.normalized()
	if spitter != null and is_instance_valid(spitter) and spitter.is_alive():
		dir = (spitter.global_position + spitter.up * spitter.seg_radius - global_position).normalized()
	vel = dir * SPEED * 1.5
	_t = 0.0
	# Batted: it squashes against the tail and a few droplets fly off.
	_squash = 1.0
	_burst(5, 1.2)
	Sfx.play("swipe_hit", global_position)
	# (v107: once batted it is Gill's: a clear aqua, so it reads as no longer a threat to him.
	# Its path, speed, damage and collision are exactly as before.)
	if Juice.enabled and _mat != null:
		_mat.set_shader_parameter("core_col", Color(0.75, 1.0, 0.95))
		_mat.set_shader_parameter("rim_col", Color(0.35, 0.9, 1.0))


func _splat() -> void:
	if _done:
		return
	_done = true
	_burst(7, 1.6)
	WaterFX.inst.sparkle(global_position, Color(0.75, 1.0, 0.3, 0.9), 6, 1.2, 0.06, 0.6)
	_splash()
	Sfx.play("parasite_splat", global_position, -4.0)
	live.erase(self)
	if spitter != null and is_instance_valid(spitter) and spitter._glob == self:
		spitter._glob = null
	queue_free()


## A few slimy droplets flung out (WaterFX puffs: they fade by themselves, nothing accumulates).
func _burst(n: int, speed: float) -> void:
	for i in n:
		var fx := WaterFX._fx_rng
		var d := Vector3(fx.randf() - 0.5, fx.randf() - 0.5, fx.randf() - 0.5).normalized()
		WaterFX.inst._spawn_puff(global_position + d * RADIUS, d * speed, 0.35, 0.05, Color(0.78, 1.0, 0.3, 0.75), 0.45)


## The splat: a flattened blob of the same slime that spreads and fades in a third of a second, then
## is freed (it is the glob's own node: the glob is gone, only this lingers briefly).
func _splash() -> void:
	var sp := MeshInstance3D.new()
	sp.mesh = _blob_mesh
	var m := _mat.duplicate() as ShaderMaterial
	m.set_shader_parameter("stretch", 0.0)
	m.set_shader_parameter("squash", 1.0)
	sp.material_override = m
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var host := get_parent()
	if host == null:
		return
	host.add_child(sp)
	sp.global_transform = Transform3D(global_basis.orthonormalized().scaled(Vector3.ONE * RADIUS * 1.3), global_position)
	var tw := sp.create_tween()
	tw.set_parallel(true)
	tw.tween_property(sp, "scale", sp.scale * 2.0, 0.32)
	tw.tween_method(func(f: float) -> void: m.set_shader_parameter("fade", f), 1.0, 0.0, 0.32)
	tw.chain().tween_callback(sp.queue_free)


func _exit_tree() -> void:
	live.erase(self)


## Globs of `b` still flying at the axolotl (they count toward the attack budget).
static func incoming_on(b: MossBall) -> int:
	var k := 0
	for gl in live:
		if gl.ball == b and not gl.reflected and not gl._done:
			k += 1
	return k


static func _seg_dist(pt: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var k := clampf((pt - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return pt.distance_to(a + ab * k)
