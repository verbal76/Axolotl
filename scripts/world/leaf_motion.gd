class_name LeafMotion
extends Node
## Platform leaves feel alive (owner, 2026-10-01): a landing makes the leaf give a little and spring
## back, settling within about a second, and a ball's water current leans the blades along the flow.
## Purely visual: collision, footing, jumps and climbs are untouched (it is not a trampoline).
##
## One damped spring for the leaf under the axolotl drives its ball's leaf material (`press`, see
## plant.gdshader); his model rides the same dip, so he never hovers over the bent blade. The
## current sway is the shader's own (per-leaf phase), from the ball's current set once here.

const K := 70.0          # spring stiffness (1/s^2): a quick, slightly underdamped give
const C := 9.0           # damping: one soft rebound, settled in ~1 s
const STAND := 0.025     # m of give while he stands on a leaf
const KICK_MIN := 0.25   # landing kick (m/s), by impact
const KICK_MAX := 0.7
const MAX_DIP := 0.09    # m

var g: Node
var y := 0.0             # current dip (m, downward)
var v := 0.0
var _ball: MossBall
var _at := Vector3.ZERO
var _active := false


func setup(p_g: Node) -> void:
	g = p_g
	for b in g.balls:
		var bb := b as MossBall
		if bb.leaf_mat != null and bb.current_strength > 0.0:
			bb.leaf_mat.set_shader_parameter("cur_axis", bb.current_axis)
			bb.leaf_mat.set_shader_parameter("cur_strength", bb.current_strength)


## The leaf body he stands on, or null (static leaf platforms and stem ladders carry "leaves").
static func leaf_under(p: Node) -> Node:
	if p == null or not p.grounded:
		return null
	var col: Object = p._floor_collider()
	if col is Node and (col as Node).has_meta("leaves") and not (col as Node).has_method("absorb"):
		return col as Node
	return null


## Axolotl._on_land: he came down on a leaf at `at` with `impact` (m/s).
func landed(ball: MossBall, at: Vector3, impact: float) -> void:
	if _ball != null and _ball != ball:
		_clear()
	_ball = ball
	_at = at
	_active = true
	v += clampf(impact * 0.05, KICK_MIN, KICK_MAX)


func _physics_process(dt: float) -> void:
	if g == null or not _active:
		return
	var p = g.player
	var on := leaf_under(p) != null
	if on:
		_at = p.global_position
	var target := STAND if on else 0.0
	v += (-K * (y - target) - C * v) * dt
	y = clampf(y + v * dt, -MAX_DIP * 0.5, MAX_DIP)
	if not on and absf(y) < 0.0005 and absf(v) < 0.005:
		_clear()
		return
	if _ball != null and _ball.leaf_mat != null:
		_ball.leaf_mat.set_shader_parameter("press", Vector4(_at.x, _at.y, _at.z, y))
	if p != null and p.model != null:
		p.model.position.y = -y if on else 0.0


func _clear() -> void:
	y = 0.0
	v = 0.0
	_active = false
	if _ball != null and _ball.leaf_mat != null:
		_ball.leaf_mat.set_shader_parameter("press", Vector4.ZERO)
	var p = g.player if g != null else null
	if p != null and p.model != null:
		p.model.position.y = 0.0
	_ball = null
