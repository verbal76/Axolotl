class_name LeafHopper
extends Critter
## A skittish leaf hopper living on a climb (docs/ECOSYSTEM.md). When the axolotl comes near it
## springs up to the next leaf or two of the climb, always upward, so following it shows the way
## up. At the top it waits; when he reaches it there it leaps all the way back down to the first
## leaves and starts again. Harmless.

const SPOOK_R := 3.2
const HOP_TIME := 0.55

## The climb it lives on: points on each step, lowest first.
var steps: Array = []
var index := 1
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _hop := -1.0
var _rest := 0.0
var _body: Node3D


func place(p_ball: MossBall, p_steps: Array, start_index: int, seed_v: int) -> void:
	setup(p_ball, "hopper", "climbs", seed_v)
	seen_radius = 4.5
	p_ball.add_child(self)
	steps = p_steps
	index = clampi(start_index, 0, steps.size() - 1)
	global_position = steps[index]
	_build()


func late_place() -> void:
	global_position = _perch(index)
	_orient(Vector3.ZERO)


func _build() -> void:
	# One mesh: a wedge-shaped leaf-green body, head, folded hind legs and feelers. It squashes
	# and stretches as it springs.
	_body = Node3D.new()
	add_child(_body)
	var green := Color(0.45, 0.8, 0.25)
	var dark := Color(0.2, 0.35, 0.1)
	var parts := [[Critter.sphere(0.07, 8), green, Critter.xf(Vector3(0, 0.07, 0), Vector3(0.8, 0.8, 2.0))],
			[Critter.sphere(0.045, 6), green, Critter.xf(Vector3(0, 0.1, -0.13))]]
	for side in [-1.0, 1.0]:
		parts.append([Critter.sphere(0.02, 5), dark, Critter.xf(Vector3(side * 0.07, 0.11, 0.12), Vector3(1.0, 1.0, 5.0))])
		parts.append([Critter.sphere(0.012, 4), dark, Critter.xf(Vector3(side * 0.03, 0.14, -0.2), Vector3(1.0, 1.0, 8.0))])
		parts.append([Critter.sphere(0.018, 4), Color(0.1, 0.1, 0.05), Critter.xf(Vector3(side * 0.035, 0.12, -0.16))])
	Critter.part(Critter.merge(parts), Critter.vc_mat(), _body)


## A point on step `i` (slightly above its surface).
func _perch(i: int) -> Vector3:
	var p: Vector3 = steps[i]
	var hit := ground_under(p, LEAF_MASK, 0.5, 1.0)
	return ((hit["position"] as Vector3) if hit else p) + ball.up_at(p) * 0.02


func tick(dt: float) -> void:
	if _hop >= 0.0:
		_hop += dt / HOP_TIME
		var k := clampf(_hop, 0.0, 1.0)
		var up := ball.up_at(_to)
		var arc := 4.0 * k * (1.0 - k) * (0.6 + _from.distance_to(_to) * 0.25)
		global_position = _from.lerp(_to, k) + up * arc
		_body.scale = Vector3(0.9, 1.25, 0.9).lerp(Vector3.ONE, k)
		if _hop >= 1.0:
			_hop = -1.0
			_rest = 0.4
			_body.scale = Vector3.ONE
		return
	_rest -= dt
	var p := player()
	if _rest > 0.0 or not player_here():
		return
	if p.global_position.distance_to(global_position) < SPOOK_R:
		var next := index + 1 + (1 if rng.randf() < 0.3 else 0)
		if index >= steps.size() - 1:
			next = rng.randi_range(0, mini(2, steps.size() - 1))
		_jump_to(mini(next, steps.size() - 1))


func _jump_to(i: int) -> void:
	_from = global_position
	index = i
	_to = _perch(i)
	_hop = 0.0
	_orient(_to - _from)


func _orient(fwd: Vector3) -> void:
	var up := ball.up_at(global_position)
	if fwd.length() < 0.01:
		fwd = MossBall.frame_at(up, rng.randf() * 360.0).z
	fwd = (fwd - up * fwd.dot(up)).normalized()
	global_basis = Basis(fwd.cross(up).normalized(), up, -fwd).orthonormalized().scaled(Vector3.ONE * 1.8)
