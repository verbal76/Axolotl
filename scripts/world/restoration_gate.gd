class_name RestorationGate
extends AnimatableBody3D
## A piece of the world that changes when its restoration zone heals (world expansion: restoration
## changes geography, docs/WORLD_EXPANSION.md). Kinds:
##   "rise"     moves from `closed_xf` to `open_xf` (a fallen stem lifts into a bridge, a root
##              curtain draws up out of a doorway);
##   "grow"     grows from a bud at `closed_xf` to full size at `open_xf`; solid only once grown
##              (leaves unfurling into stepping stones);
##   "retract"  shrinks away from `closed_xf` into `open_xf` and is gone; stops blocking at once
##              (debris clearing from a tunnel, a root curtain drawing up);
##   "column"   a bubble column that starts flowing (its bubbles appear, it lifts) once healed.
## Healed live it plays out over `duration`; resumed from a save it is simply open. It never moves
## into him: it waits while he stands where it is going. Children (meshes, collision shapes) are
## built by the level in the gate's open pose.

signal opened_fully

var ball: MossBall
var zone_id := ""
var kind := "rise"
var closed_xf := Transform3D.IDENTITY
var open_xf := Transform3D.IDENTITY
var duration := 2.5
var is_open := false
var _t := -1.0
## How strongly a "column" gate's bubbles flow (0 shut, 1 full).
var flow := 0.0


func setup(p_ball: MossBall, p_zone: String, p_kind: String, p_closed: Transform3D, p_open: Transform3D, p_duration := 2.5) -> void:
	ball = p_ball
	zone_id = p_zone
	kind = p_kind
	closed_xf = p_closed
	open_xf = p_open
	duration = p_duration
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	set_meta("restoration_gate", zone_id)
	ball.gates.append(self)


func _ready() -> void:
	_apply(1.0 if is_open else 0.0)


## Opens it: played out when healed live (`animate`), at once when a save resumes.
func open(animate: bool) -> void:
	if is_open or _t >= 0.0:
		return
	if not animate or not is_inside_tree():
		is_open = true
		# (Straight there, not on the next physics step.)
		var sync := sync_to_physics
		sync_to_physics = false
		_apply(1.0)
		sync_to_physics = sync
		# (The body too: with physics sync on, moving the node alone left the collision where it
		# stood shut, so a resumed save's raised bridge had nothing under it.)
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform)
		set_meta("settled", true)
		return
	_t = 0.0
	Sfx.play("restore", global_position, -4.0)


func _physics_process(dt: float) -> void:
	if _t < 0.0:
		return
	if kind in ["rise", "grow"] and _player_in_way():
		return
	_t += dt / duration
	var k := smoothstep(0.0, 1.0, minf(_t, 1.0))
	_apply(k)
	if _t >= 1.0:
		_t = -1.0
		is_open = true
		set_meta("settled", true)
		opened_fully.emit()


func _apply(k: float) -> void:
	var xf := closed_xf.interpolate_with(open_xf, k)
	match kind:
		"grow":
			var s := lerpf(0.15, 1.0, k)
			xf.basis = xf.basis.scaled(Vector3(s, s, s))
			_set_solid(k >= 1.0)
		"retract":
			var s2 := lerpf(1.0, 0.1, k)
			xf.basis = xf.basis.scaled(Vector3(s2, s2, s2))
			_set_solid(k <= 0.0)
			# Gone once cleared (owner, 2026-10-02: a shrunken curtain was left floating over its
			# doorway).
			visible = k < 1.0
		"column":
			visible = k > 0.0
			flow = k
			for c in get_children():
				if c is AudioStreamPlayer3D and k > 0.0 and not (c as AudioStreamPlayer3D).playing and is_inside_tree():
					(c as AudioStreamPlayer3D).play()
		_:
			_set_solid(true)
	if is_inside_tree():
		global_transform = xf
	else:
		transform = xf


func _set_solid(on: bool) -> void:
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = not on


## Whether he stands where the gate is heading (inside its open bounds, with a margin).
func _player_in_way() -> bool:
	var g := Game.inst
	if g == null or g.player == null or g.player.ball != ball:
		return false
	var local := open_xf.affine_inverse() * g.player.body_center()
	var box := _local_bounds().grow(0.5)
	return box.has_point(local)


func _local_bounds() -> AABB:
	var box := AABB()
	var first := true
	for c in get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			var b := (c as MeshInstance3D).transform * (c as MeshInstance3D).mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
	return box
