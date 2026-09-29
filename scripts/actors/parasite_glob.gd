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
var _halo_mat: StandardMaterial3D


## Launched from `from` toward `target` (both world positions).
func launch(p_spitter: Parasite, p_ball: MossBall, from: Vector3, target: Vector3) -> void:
	spitter = p_spitter
	ball = p_ball
	vel = (target - from).normalized() * SPEED
	p_ball.add_child(self)
	global_position = from
	live.append(self)


func _ready() -> void:
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	core.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.85, 1.0, 0.3)
	core.material_override = m
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	# A soft glowing halo so it reads in murky water and bright water alike.
	var halo := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = RADIUS * 2.1
	hm.height = RADIUS * 4.2
	hm.radial_segments = 12
	hm.rings = 6
	halo.mesh = hm
	_halo_mat = StandardMaterial3D.new()
	_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.albedo_color = Color(0.6, 1.0, 0.25, 0.35)
	_halo_mat.no_depth_test = false
	halo.material_override = _halo_mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)


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
		for par in ball.parasites:
			if par.is_alive() and par.closest_body_point(to).distance_to(to) < RADIUS + par.body_extent() + 0.15:
				par.hit(1, from)
				global_position = to
				_splat()
				return
	global_position = to
	_halo_mat.albedo_color.a = 0.28 + 0.12 * sin(_t * 18.0)
	_trail_t -= dt
	if _trail_t <= 0.0:
		_trail_t = 0.07
		WaterFX.inst.sparkle(to, Color(0.7, 1.0, 0.3, 0.7), 2, 0.3, 0.05, 0.5)
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
	Sfx.play("swipe_hit", global_position)


func _splat() -> void:
	if _done:
		return
	_done = true
	WaterFX.inst.sparkle(global_position, Color(0.75, 1.0, 0.3, 0.9), 14, 1.6, 0.07, 0.8)
	Sfx.play("parasite_splat", global_position, -4.0)
	live.erase(self)
	if spitter != null and is_instance_valid(spitter) and spitter._glob == self:
		spitter._glob = null
	queue_free()


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
