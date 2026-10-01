class_name Presentation
extends Node
## The aquarium experiences (docs/AQUARIUM.md), reached from the title screen and the pause menu:
##   room     the bedroom, the tank as its focal point (tap the tank to look closer)
##   inspect  Aquarium Inspection: leaning in at the glass, dragging round the front of the tank
##   live     Live Tank: the phone as the tank's glass, the player's own aquarium as a living display
##   swim     Swim Mode: Gill swimming freely anywhere in the tank's water
##
## Rules (the run is never touched):
## - The run clock does not count here (Game.state is "aquarium"); the run is saved on the way in.
## - Gameplay stands still: the gameplay axolotl is frozen and hidden exactly where he was, and put
##   back exactly there (never moved) on the way out; parasites, Motes and food pause.
## - What is shown is the player's real aquarium (restoration, water, plants, creatures, his look):
##   the same world, never a second copy. In the room, inspection and Live Tank a cosmetic stand-in
##   of Gill idles where he really is; in Swim Mode a separate swimmer body (Swimmer) that nothing
##   in the run reacts to.

const INSPECT_CENTRE := Vector3(0, 10, -20)
const INSPECT_DIST := 640.0
const INSPECT_YAW := 0.7
const INSPECT_PITCH := Vector2(-0.12, 0.34)
## Live Tank viewpoints: [name, offset of the camera from the front glass centre, look target].
const LIVE_VIEWS := [["tank", Vector3(0, 20, 330), Vector3(0, 12, -20)], ["left", Vector3(-150, 10, 260), Vector3(-150, 0, -20)],
		["right", Vector3(150, 10, 260), Vector3(150, 0, -20)], ["gill", Vector3.ZERO, Vector3.ZERO]]

var mode := ""
var from := ""
var g: Game
var ui: PresentationUi
var standin: AxolotlModel
var swimmer: Swimmer
var live_view := 0
var inspect_yaw := 0.0
var inspect_pitch := 0.12
var _snap := {}
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _t := 0.0
# The stand-in explores the water round where Gill really is (GillExplorer).
var _home := Vector3.ZERO
var _home_ball: MossBall
var explorer: GillExplorer
## The Gill close-up's camera: which of GILL_CAM it is using, and its sphere cast.
var _gill_cam_k := 0
var _gill_cam_q: PhysicsShapeQueryParameters3D
var _cam_upv := Vector3.ZERO


func _init() -> void:
	name = "Presentation"


func active() -> bool:
	return mode != ""


## Opens the bedroom. `p_from`: "title" or "play" (where Back finally returns).
func enter(p_from: String) -> void:
	if mode != "" or g == null:
		return
	from = p_from
	var p := g.player
	if from == "play":
		g.save_run()
	_snap = {"state": g.state, "pos": p.global_position, "basis": p.global_basis, "vel": p.velocity, "facing": p.facing,
			"pstate": p.state, "controls": p.controls_enabled, "visible": p.visible, "cam_target": g.cam.target, "fov": g.cam.fov,
			"cine": g.cam.cinematic}
	if g.t2 != null:
		g.t2.cancel()
	g.state = "aquarium"
	p.state = "presentation"
	p.controls_enabled = false
	p.velocity = Vector3.ZERO
	p.visible = false
	g.cam.target = null
	g.cam.cinematic = false
	g.hud.visible_controls(false)
	g.title.hide_title()
	g.aquarium.set_outside_view(true)
	_home = p.global_position
	_home_ball = p.ball
	standin = AxolotlModel.new()
	standin.name = "GillStandIn"
	g.add_child(standin)
	start_explorer(_home_ball, _home, p.facing)
	ui.visible = true
	go("room", true)


func go(m: String, snap := false) -> void:
	if m != "swim" and swimmer != null:
		_end_swim()
	var was_out := _outside() if mode != "" else true
	mode = m
	g.aquarium.set_outside_view(_outside())
	# Into or out of the water is a cut (never a glide through the glass).
	snap = snap or was_out != _outside()
	match m:
		"room":
			g.cam.fov = 48.0
		"inspect":
			g.cam.fov = 44.0
			inspect_yaw = 0.0
			inspect_pitch = 0.12
		"live":
			g.cam.fov = _live_fov() if LIVE_VIEWS[live_view][0] != "gill" else 50.0
		"swim":
			_start_swim()
			g.cam.fov = 70.0
	if standin:
		standin.visible = m != "swim"
	if snap and explorer:
		# (A cut: the only moment a last-resort relocation may happen, unseen.)
		explorer.on_cut()
	var tgt := _camera_target(0.0)
	if snap:
		_cam_pos = tgt[0]
		_cam_look = tgt[1]
	ui.set_mode(m)


## Back: one step out (Swim, Live Tank, Inspection -> the room; the room -> where it came from).
func back() -> void:
	if mode == "":
		return
	if mode == "room":
		exit()
	else:
		go("room")


func exit() -> void:
	if mode == "":
		return
	if swimmer:
		_end_swim()
	mode = ""
	ui.visible = false
	if standin:
		standin.queue_free()
		standin = null
	if explorer:
		explorer.free_body()
		explorer = null
	g.aquarium.set_outside_view(false)
	var p := g.player
	p.global_position = _snap["pos"]
	p.global_basis = _snap["basis"]
	p.velocity = _snap["vel"]
	p.facing = _snap["facing"]
	p.state = _snap["pstate"]
	p.visible = _snap["visible"]
	g.cam.fov = _snap["fov"]
	g.cam.target = _snap["cam_target"]
	g.cam.cinematic = _snap["cine"]
	g.state = _snap["state"]
	if from == "title":
		g._enter_title()
	else:
		p.controls_enabled = _snap["controls"]
		g.hud.visible_controls(true)
		g.cam.snap_behind()
	_snap = {}


func _process(dt: float) -> void:
	if mode == "":
		return
	_t += dt
	if standin and explorer and mode != "swim":
		explorer.step(dt)
		_apply_explorer()
	if swimmer:
		_swim_step(dt)
	var tgt := _camera_target(dt)
	var k := 1.0 - exp(-dt * (7.0 if mode == "swim" else 3.0))
	_cam_pos = _cam_pos.lerp(tgt[0], k)
	_cam_look = _cam_look.lerp(tgt[1], k)
	g.cam.global_position = _cam_pos
	g.aquarium.outside_camera(_cam_pos)
	if _cam_pos.distance_to(_cam_look) > 0.01:
		g.cam.look_at(_cam_look, _cam_up(dt))


## [camera position, look target] for the current mode.
func _camera_target(_dt: float) -> Array:
	match mode:
		"room":
			var bed: Bedroom = g.aquarium.bedroom
			# (A slow breath of movement, as if standing in the doorway.)
			return [bed.view_pos + Vector3(sin(_t * 0.21) * 8.0, sin(_t * 0.17) * 5.0, 0), bed.view_look]
		"inspect":
			var cp := cos(inspect_pitch)
			var pos := INSPECT_CENTRE + Vector3(sin(inspect_yaw) * cp, sin(inspect_pitch), cos(inspect_yaw) * cp) * INSPECT_DIST
			return [pos, INSPECT_CENTRE + Vector3(sin(inspect_yaw) * -40.0, 0, 0)]
		"live":
			var v: Array = LIVE_VIEWS[live_view]
			if v[0] == "gill" and standin and explorer:
				return _gill_camera()
			var drift := Vector3(sin(_t * 0.05) * 3.0, sin(_t * 0.037) * 2.0, 0)
			return [Vector3(0, 0, Aquarium.TANK_MAX.z) + (v[1] as Vector3) + drift, v[2]]
		"swim":
			var fwd := swimmer.cam_forward()
			var pivot := swimmer.global_position + Vector3.UP * 0.45
			var want := pivot - fwd * 4.2 + Vector3.UP * 0.6
			var q := PhysicsRayQueryParameters3D.create(pivot, want, 1 | 2 | Aquarium.TANK_LAYER_BIT)
			var hit := swimmer.get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				want = pivot + (want - pivot).normalized() * maxf(0.6, pivot.distance_to(hit["position"]) - 0.3)
			return [want, pivot + fwd * 2.0]
	return [_cam_pos, _cam_look]


## The camera's up: the world's, except in the Gill close-up, where it is the moss ball's up where
## he is (eased), so the ground is level wherever on the ball he swims.
func _cam_up(dt: float) -> Vector3:
	if not (mode == "live" and LIVE_VIEWS[live_view][0] == "gill" and explorer):
		_cam_upv = Vector3.ZERO
		return Vector3.UP
	var want := _home_ball.up_at(explorer.p)
	if _cam_upv == Vector3.ZERO or dt <= 0.0:
		_cam_upv = want
	else:
		_cam_upv = _cam_upv.slerp(want, 1.0 - exp(-dt * 2.0)).normalized()
	var fwd := (_cam_look - _cam_pos).normalized()
	if absf(fwd.dot(_cam_upv)) > 0.97:
		# (Looking straight down at him: his heading is up on the screen.)
		return explorer.face
	return _cam_upv


## Live Tank: the vertical field of view that fits the tank's width (a little inside the glass).
func _live_fov() -> float:
	var vp := g.get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(1.0, vp.y)
	var half_w := 285.0
	var dist := 330.0
	var h := 2.0 * atan(half_w / dist)
	var v := 2.0 * atan(tan(h * 0.5) / aspect)
	return clampf(rad_to_deg(v), 30.0, 60.0)


func next_live_view() -> void:
	live_view = (live_view + 1) % LIVE_VIEWS.size()
	g.cam.fov = _live_fov() if LIVE_VIEWS[live_view][0] != "gill" else 50.0
	g.aquarium.set_outside_view(_outside())
	# (A cut, not a glide through the glass.)
	if explorer:
		explorer.on_cut()
	var tgt := _camera_target(0.0)
	_cam_pos = tgt[0]
	_cam_look = tgt[1]


## Whether the camera is in the room (true) or in the water (Swim Mode, Live Tank's close-up).
func _outside() -> bool:
	return not (mode == "swim" or (mode == "live" and LIVE_VIEWS[live_view][0] == "gill"))


## Inspection: dragging looks round the front of the tank (bounded, smoothed; never inside it).
func inspect_drag(delta: Vector2) -> void:
	inspect_yaw = clampf(inspect_yaw - delta.x * 0.004, -INSPECT_YAW, INSPECT_YAW)
	inspect_pitch = clampf(inspect_pitch + delta.y * 0.003, INSPECT_PITCH.x, INSPECT_PITCH.y)


## Room: whether a tap at screen point `sp` lands on the aquarium.
func tap_hits_tank(sp: Vector2) -> bool:
	var from_p := g.cam.project_ray_origin(sp)
	var dir := g.cam.project_ray_normal(sp)
	var box := AABB(Aquarium.TANK_MIN - Vector3(20, 40, 20), Aquarium.TANK_MAX - Aquarium.TANK_MIN + Vector3(40, 120, 40))
	return box.intersects_ray(from_p, dir) != null


# --- The stand-in (room, inspection, Live Tank) ----------------------------------------------

## His explorer round `home` on `ball` (also used by the tests to set him down anywhere).
func start_explorer(ball: MossBall, home: Vector3, facing: Vector3) -> void:
	if explorer:
		explorer.free_body()
	_home = home
	_home_ball = ball
	explorer = GillExplorer.new()
	explorer.model = standin
	var hk := Vector3i((home * 10.0).round())
	explorer.setup(g, ball, home, facing, hash([ball.index, hk.x, hk.y, hk.z]))
	_apply_explorer()
	standin.reset_follow()


## The stand-in model where the explorer has him, moving as he moves.
func _apply_explorer() -> void:
	var e := explorer
	standin.global_transform = e.model_xf
	standin.swim = e.swim_effort
	standin.swim_turn = clampf(e.yaw_v, -3.0, 3.0)
	standin.swim_pitch = 0.0
	standin.speed = clampf(e.speed / Swimmer.RELAXED, 0.0, 1.0) * 0.4
	standin.grounded = e.grounded
	standin.conform = e.conform
	standin.idle_ok = e.idle_ok


## Offsets round him the Gill close-up tries, in order: [yaw offset (rad), height (m)].
const GILL_CAM := [[0.0, 0.9], [0.5, 0.9], [-0.5, 0.9], [1.0, 1.3], [-1.0, 1.3], [0.0, 1.8], [1.7, 1.2], [-1.7, 1.2],
		[PI, 1.0], [0.0, 2.6]]
## The close-up never comes nearer than his body length (nose to tail tip).
const GILL_CAM_MIN := 1.35


## The Gill close-up: a quiet nature camera in the water beside him, slowly circling. It keeps
## clear of the scenery (terrain, leaves, climbable stems) and never comes closer than his length:
## if the way to its place is blocked it moves round him to the nearest open view.
func _gill_camera() -> Array:
	var e := explorer
	var s := e.p
	var up := _home_ball.up_at(s)
	var pivot := s + up * (0.35 if e.grounded else 0.1)
	var space := g.get_world_3d().direct_space_state
	if _gill_cam_q == null:
		_gill_cam_q = PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.2
		_gill_cam_q.shape = sph
		_gill_cam_q.collision_mask = 1 | 2 | 8 | Aquarium.TANK_LAYER_BIT
	var q := _gill_cam_q
	q.transform = Transform3D(Basis.IDENTITY, pivot)
	var best := Vector3.INF
	var best_d := -1.0
	var best_k := _gill_cam_k
	# (The view it has first, so it stays put while that is open; then the others in order.)
	var order := [_gill_cam_k]
	for k in GILL_CAM.size():
		if k != _gill_cam_k:
			order.append(k)
	for k in order:
		var o: Array = GILL_CAM[k]
		var fr := MossBall.frame_at(up, rad_to_deg(_t * 0.06 + float(o[0])))
		var want := pivot + up * float(o[1]) + fr.z * (2.6 if float(o[1]) < 2.0 else 0.8)
		q.motion = want - pivot
		var f: float = space.cast_motion(q)[0]
		var d := f * pivot.distance_to(want)
		if f >= 0.999:
			_gill_cam_k = k
			return [want, pivot]
		if d > best_d:
			best_d = d
			best = pivot + (want - pivot).normalized() * maxf(0.0, d - 0.1)
			best_k = k
	_gill_cam_k = best_k
	if best_d < GILL_CAM_MIN:
		# (Nowhere open at his length: straight above, as high as the water allows.)
		q.motion = up * 3.0
		var fu: float = space.cast_motion(q)[0]
		return [pivot + up * maxf(GILL_CAM_MIN, fu * 3.0 - 0.1), pivot]
	return [best, pivot]


# --- Swim Mode ---------------------------------------------------------------------------------

func _start_swim() -> void:
	g.aquarium.ensure_tank_body()
	swimmer = Swimmer.new()
	swimmer.name = "Swimmer"
	g.add_child(swimmer)
	var p := g.player
	# He sets off from where Gill really is, just off the ground.
	swimmer.setup(_home + p.ball.up_at(_home) * 0.8, p.facing, Aquarium.TANK_LAYER_BIT)
	g.fish.reactivity = 1.8


func _end_swim() -> void:
	if swimmer:
		swimmer.queue_free()
		swimmer = null
	g.fish.reactivity = 1.0


func _swim_step(_dt: float) -> void:
	swimmer.stick = ui.swim_stick
	swimmer.swim_held = ui.swim_held
	swimmer.invert_y = Settings.swim_invert_y
	var fp: Vector3 = g.fish.nearest_point(swimmer.global_position)
	if fp != Vector3.INF and fp.distance_to(swimmer.global_position) < 6.0:
		swimmer.notice_fish(fp)


## Where Gill is, for the fish to notice (Swim Mode: the swimmer; elsewhere here: nowhere).
func gill_point() -> Vector3:
	if swimmer:
		return swimmer.global_position
	return Vector3.INF
