class_name PracticeTarget
extends Critter
## A harmless practice target a Tier-2 shrine sets out (docs/TIER2.md): a loose puff of algae spores
## floating at about head height. It never moves toward Gill or hurts him; any hit pops it. Struck
## and targeted like a hostile (so a new ability has something to try itself on), it is not a
## creature of the ecosystem, not food and not a completion entry. It fades away after LIFE seconds
## or once Gill has gone far from it.

const LIFE := 90.0
const FAR := 30.0

var _home := Vector3.ZERO
var _age := 0.0
var _phase := 0.0
var _body: MeshInstance3D
var _mat: StandardMaterial3D


## `seed_v` seeds its own bobbing (never the gameplay generator).
func place(p_ball: MossBall, pos: Vector3, seed_v: int) -> void:
	ball = p_ball
	species = "practice"
	habitat = "shrine"
	rng.seed = seed_v
	active = true
	hp = 1
	p_ball.add_child(self)
	_home = pos
	_phase = rng.randf() * TAU
	global_position = pos
	_body = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.64
	sm.radial_segments = 12
	sm.rings = 6
	_body.mesh = sm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.46, 0.5, 0.26)
	_mat.emission_enabled = true
	_mat.emission = Color(0.55, 0.7, 0.25)
	_mat.emission_energy_multiplier = 0.35
	_mat.roughness = 0.9
	_body.material_override = _mat
	add_child(_body)
	# Knobbly spore clumps.
	for i in 6:
		var n := MeshInstance3D.new()
		var ns := SphereMesh.new()
		ns.radius = 0.12
		ns.height = 0.24
		ns.radial_segments = 8
		ns.rings = 4
		n.mesh = ns
		n.material_override = _mat
		var a := TAU * i / 6.0
		n.position = Vector3(cos(a) * 0.28, sin(a * 2.0) * 0.12, sin(a) * 0.28)
		_body.add_child(n)


func _process(dt: float) -> void:
	if defeated or Game.paused_for_aquarium():
		return
	_age += dt
	var up := ball.up_at(_home)
	global_position = _home + up * sin(_age * 1.3 + _phase) * 0.12
	_body.rotation.y += dt * 0.4
	var p := player()
	if _age > LIFE or (p != null and (p.ball != ball or p.global_position.distance_to(_home) > FAR)):
		remove()


func hittable() -> bool:
	return not defeated


func is_hidden() -> bool:
	return true


func closest_body_point(pt: Vector3) -> Vector3:
	var d := pt - global_position
	return global_position + d.normalized() * minf(0.32, d.length()) if d.length() > 0.001 else global_position


func body_extent() -> float:
	return 0.08


func hit(_stages: int, _from_pos: Vector3) -> bool:
	if defeated:
		return false
	defeated = true
	WaterFX.inst.sparkle(global_position, Color(0.8, 0.95, 0.5, 0.9), 14, 1.5, 0.07, 0.8)
	Sfx.play("drain", global_position, -8.0)
	remove()
	return true


func remove() -> void:
	defeated = true
	if Game.inst:
		Game.inst.practice_targets.erase(self)
	queue_free()
