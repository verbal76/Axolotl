extends RefCounted
## CPU cost breakdown: measures physics/process frame time per moss ball with categories of
## nodes toggled off, to find hot spots.

var t


func _avg(n: int) -> Array:
	await t.frames(5)
	var t0 := Time.get_ticks_usec()
	await t.frames(n)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
	return [ms, 0.0]


func _toggle(nodes: Array, on: bool) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.set_physics_process(on)


func run(runner) -> void:
	t = runner
	var g: Game = t.g
	for bi in 3:
		var b := g.balls[bi]
		g.player.place(b, b.surface_point(MossBall.dir_ll(10, 30), 0.2), Vector3.FORWARD)
		g.cam.snap_behind()
		await t.seconds(1.0)
		var base: Array = await _avg(120)
		t.log_line("ball %d baseline: %.2f ms per frame (whole engine, headless)" % [bi + 1, base[0]])
		var groups := {"parasites": [], "foods": [], "motes": [], "platforms": [], "player": [g.player]}
		for bb in g.balls:
			groups["parasites"].append_array(bb.parasites)
			groups["foods"].append_array(bb.foods)
			groups["motes"].append_array(bb.motes)
			groups["platforms"].append_array(bb.crumbles + bb.flex_leaves)
			for c in bb.get_meta("builder").root.get_children():
				if c is Platforms.SwayLeaf:
					groups["platforms"].append(c)
		for k in groups:
			_toggle(groups[k], false)
			var r: Array = await _avg(90)
			_toggle(groups[k], true)
			t.log_line("  without %-9s %.2f ms (saves %.2f)" % [k, r[0], base[0] - r[0]])
