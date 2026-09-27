extends RefCounted
## Rendered close-ups of the axolotl model for visual review (not a pass/fail suite).
## godot --path . -- --test=model --out=DIR

var t
var g: Game
var cam: Camera3D


func run(runner) -> void:
	t = runner
	g = t.g
	var p := g.player
	p.invuln_t = 9999
	g.hud.visible = false
	var b := g.balls[0]
	var dir := MossBall.dir_ll(10, 30)
	p.place(b, b.surface_point(dir, 0.1), Vector3.FORWARD)
	cam = Camera3D.new()
	cam.fov = 40
	g.add_child(cam)
	cam.make_current()
	await t.seconds(1.0)
	# Static views.
	for v in [["front", Vector3(0, 0.5, -1.9)], ["three_quarter", Vector3(1.3, 0.7, -1.4)], ["side", Vector3(2.1, 0.45, 0.2)],
			["back_game_view", Vector3(0.0, 1.2, 2.6)], ["top", Vector3(0.01, 2.6, 0.3)]]:
		await _view(v[0], v[1])
	# Health states on the gills: 3 of 3, 2 of 4 (one lost, one grown), 6 of 6, 1 of 3.
	for h in [[3, 3], [2, 4], [6, 6], [1, 3]]:
		p.health = h[0]
		p.max_health = h[1]
		p.model.set_health(h[0], h[1], false)
		await t.seconds(1.2)
		await _shot("gills_%d_of_%d" % [h[0], h[1]], Vector3(0.9, 1.1, 1.3))
	p.health = 3
	p.max_health = 3
	p.model.set_health(3, 3, false)
	# Walking: follow him with the camera, several gait frames from above/side.
	p.use_bot_input = true
	p.bot_input = Vector2(0, 1)
	await t.seconds(1.0)
	for i in 4:
		await t.frames(7)
		await _shot("walk_%d" % i, Vector3(1.6, 1.6, 0.4))
	await _shot("walk_top", Vector3(0.01, 2.8, 0.2))
	# Jump + burst.
	await t.frames(1)
	Input.action_press("jump")
	await t.frames(1)
	Input.action_release("jump")
	await t.frames(12)
	await _shot("jump_rise", Vector3(1.9, 0.6, 0.6))
	Input.action_press("jump")
	await t.frames(1)
	Input.action_release("jump")
	await t.frames(6)
	await _shot("burst", Vector3(1.9, 0.6, 0.6))
	p.bot_input = Vector2.ZERO
	await t.seconds(1.5)
	# Swipe.
	Input.action_press("swipe")
	await t.frames(1)
	Input.action_release("swipe")
	await t.frames(9)
	await _shot("swipe", Vector3(0.01, 2.6, 0.6))
	p.use_bot_input = false


## Camera offset is in the axolotl's local frame (x right, y up, z back).
func _place_cam(off: Vector3) -> void:
	var p := g.player
	var basis: Basis = p.model.global_transform.basis.orthonormalized()
	var target := p.model.global_position + basis.y * 0.25 + basis.z * 0.15
	cam.global_position = p.model.global_position + basis * off
	cam.look_at(target, basis.y)


func _view(name_: String, off: Vector3) -> void:
	_place_cam(off)
	await t.frames(3)
	await _shot(name_, off)


func _shot(name_: String, off: Vector3) -> void:
	_place_cam(off)
	await t.frames(1)
	_place_cam(off)
	await t.shot("model_" + name_)
