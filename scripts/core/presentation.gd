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
var _rng := RandomNumberGenerator.new()
# The stand-in's little wanders round where Gill really is.
var _home := Vector3.ZERO
var _home_ball: MossBall
var _stand_pos := Vector3.ZERO
var _stand_face := Vector3.FORWARD
var _stand_goal := Vector3.ZERO
var _stand_wait := 2.0


func _init() -> void:
	name = "Presentation"
	_rng.seed = 0xA0A1


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
	_stand_pos = _home
	_stand_face = p.facing
	_stand_goal = _home
	_place_standin(0.0)
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
	if standin and mode != "swim":
		_wander(dt)
	if swimmer:
		_swim_step(dt)
	var tgt := _camera_target(dt)
	var k := 1.0 - exp(-dt * (7.0 if mode == "swim" else 3.0))
	_cam_pos = _cam_pos.lerp(tgt[0], k)
	_cam_look = _cam_look.lerp(tgt[1], k)
	g.cam.global_position = _cam_pos
	g.aquarium.outside_camera(_cam_pos)
	if _cam_pos.distance_to(_cam_look) > 0.01:
		g.cam.look_at(_cam_look, Vector3.UP)


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
			if v[0] == "gill" and standin:
				# A quiet nature-camera close-up in the water beside him, slowly circling.
				var s := standin.global_position
				var up := _home_ball.up_at(s)
				var fr := MossBall.frame_at(up, rad_to_deg(_t * 0.06))
				var pivot := s + up * 0.35
				var want := pivot + up * 0.9 + fr.z * 2.6
				var q := PhysicsRayQueryParameters3D.create(pivot, want, 1 | 2)
				var hit := g.get_world_3d().direct_space_state.intersect_ray(q)
				if not hit.is_empty():
					want = pivot + (want - pivot).normalized() * maxf(0.5, pivot.distance_to(hit["position"]) - 0.25)
				return [want, pivot]
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

## Now and then a short wander round where Gill really is, then a pause (his own idles play).
func _wander(dt: float) -> void:
	var b := _home_ball
	_stand_wait -= dt
	var to := _stand_goal - _stand_pos
	var up := b.up_at(_stand_pos)
	to -= up * to.dot(up)
	var moving := to.length() > 0.08
	if moving:
		var step := minf(to.length(), 0.35 * dt)
		var ang := Tier2.signed_angle(_stand_face, to.normalized(), up)
		_stand_face = _stand_face.rotated(up, ang * clampf(dt * 3.0, 0.0, 1.0)).normalized()
		_stand_pos += _stand_face * step
	elif _stand_wait <= 0.0:
		_stand_wait = _rng.randf_range(4.0, 9.0)
		var fr := MossBall.frame_at(b.up_at(_home), _rng.randf() * 360.0)
		_stand_goal = _home + fr.z * _rng.randf_range(0.3, 1.2)
	standin.speed = 0.25 if moving else 0.0
	standin.grounded = true
	standin.idle_ok = not moving
	_place_standin(dt)


func _place_standin(_dt: float) -> void:
	var b := _home_ball
	var up := b.up_at(_stand_pos)
	# Onto the ground or leaf under him (the real terrain, never floating).
	var q := PhysicsRayQueryParameters3D.create(_stand_pos + up * 1.5, _stand_pos - up * 2.0, 1 | 2 | 8)
	var hit := g.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_stand_pos = hit["position"]
	var face := (_stand_face - up * _stand_face.dot(up)).normalized()
	if face.length() < 0.1:
		face = MossBall.frame_at(up, 0.0).z
	standin.global_transform = Transform3D(Basis(face.cross(up).normalized(), up, -face).orthonormalized(), _stand_pos)


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
