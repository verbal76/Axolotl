class_name AmbientFish
extends Node3D
## About ten decorative aquarium fish (docs/AQUARIUM.md), at a middle scale (owner): 6 to 14 times
## the axolotl's length, so they read as fish in the whole-tank views and glide past impressively in play,
## without dwarfing the moss balls. Noncombatants that make the tank feel
## inhabited. They are not creatures of the ecosystem, not enemies, food or completion entries; nothing
## can target or hurt them. Four kinds, each with its own size, colours, speed, preferred depth and
## temperament:
##   tetra   x5  small, quick, a loose school in the middle water (timid: scatter together)
##   gourami x2  medium, slow, solitary, curious (drift toward Gill, then away)
##   cory    x2  small catfish near the gravel, stopping often (timid)
##   angel   x1  tall and slow, high in the water (solitary, wary)
##   bala    x3  bala sharks (owner): the largest fish, silver torpedoes with black-edged fins; a
##               fast, skittish trio cruising the open middle and upper water (scatter together)
## Steering is a light boid: a wandering waypoint in the kind's depth band, a turn-rate limit,
## schooling for tetras and bala sharks, and avoidance of the glass, the gravel, every moss ball and Gill. Gill
## coming close alerts them; very close, or a bump, sends them darting away from him (a school
## scatters, then regroups). Everything runs on this node's own random generator, never the global
## one gameplay and the test bot rely on, so the fish never change what the game does.

const COUNT := 13
## Tank interior (a margin inside the glass, above the gravel).
const MARGIN := 10.0
const KINDS := {
	"tetra": {"len": 4.0, "speed": 7.0, "turn": 2.6, "band": [0.35, 0.7], "school": true, "timid": 1.0, "col": [Color(0.3, 0.55, 0.95), Color(0.95, 0.3, 0.25), Color(0.85, 0.9, 0.95)]},
	"gourami": {"len": 8.0, "speed": 4.0, "turn": 1.3, "band": [0.25, 0.65], "school": false, "timid": 0.3, "col": [Color(0.75, 0.62, 0.45), Color(0.5, 0.65, 0.8), Color(0.92, 0.85, 0.7)]},
	"cory": {"len": 5.0, "speed": 3.0, "turn": 2.0, "band": [0.0, 0.05], "school": false, "timid": 0.8, "col": [Color(0.62, 0.58, 0.5), Color(0.25, 0.22, 0.2), Color(0.88, 0.84, 0.78)]},
	"bala": {"len": 11.0, "speed": 9.0, "turn": 1.6, "band": [0.45, 0.85], "school": true, "timid": 1.2, "col": [Color(0.8, 0.83, 0.86), Color(0.05, 0.05, 0.06), Color(0.9, 0.8, 0.45)]},
	"angel": {"len": 8.5, "speed": 3.2, "turn": 1.0, "band": [0.55, 0.85], "school": false, "timid": 0.6, "col": [Color(0.88, 0.86, 0.8), Color(0.15, 0.15, 0.18), Color(0.95, 0.75, 0.35)]},
}
const ROSTER := ["tetra", "tetra", "tetra", "tetra", "tetra", "gourami", "gourami", "cory", "cory", "angel", "bala", "bala", "bala"]
const FISH_SHADER := preload("res://shaders/ambient_fish.gdshader")

var fish: Array = []
var rng := RandomNumberGenerator.new()
var tank_min := Vector3.ZERO
var tank_max := Vector3.ZERO
## Solid spheres to keep clear of (moss balls): [centre, radius].
var obstacles: Array = []
## Extra reaction to Gill: 1 in play, higher in Swim Mode (he is right among them).
var reactivity := 1.0
## How big the fish are drawn (1 in play and Swim Mode). From the room (Room, Inspection, the Live
## Tank's whole-tank views) the tank is hundreds of units away and a middle-scale fish is a speck, so
## they are shown larger there; their clearances from the glass and the moss balls grow to match.
var display_scale := 1.0
var _balls: Array = []
var _meshes := {}


func setup(p_min: Vector3, p_max: Vector3, balls: Array, seed_v := 0x5f15) -> void:
	_tank = [p_min, p_max]
	_balls = balls
	rng.seed = seed_v
	_fit_bounds()
	for i in ROSTER.size():
		_spawn(ROSTER[i], i)


var _tank := [Vector3.ZERO, Vector3.ZERO]


## Glass margins and moss-ball clearances for the current display scale.
func _fit_bounds() -> void:
	var extra := 5.5 * (display_scale - 1.0)
	tank_min = _tank[0] + Vector3(MARGIN + extra, 4.0 + extra * 0.5, MARGIN + extra)
	tank_max = _tank[1] - Vector3(MARGIN + extra, 10.0 + extra * 0.5, MARGIN + extra)
	obstacles.clear()
	for b in _balls:
		obstacles.append([b.global_position, b.radius + 9.0 + extra])


func set_display_scale(s: float) -> void:
	if is_equal_approx(s, display_scale):
		return
	display_scale = s
	_fit_bounds()
	for f in fish:
		(f["node"] as MeshInstance3D).scale = Vector3.ONE * s
		(f["node"] as MeshInstance3D).set_instance_shader_parameter("pop", 1.0 if s > 1.0 else 0.0)
		f["pos"] = f["pos"].clamp(tank_min, tank_max)


func _spawn(kind: String, i: int) -> void:
	var k: Dictionary = KINDS[kind]
	var mi := MeshInstance3D.new()
	mi.name = "Fish_%s_%d" % [kind, i]
	mi.mesh = _mesh_for(kind)
	var mat := ShaderMaterial.new()
	mat.shader = FISH_SHADER
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("phase", rng.randf() * TAU)
	mi.set_instance_shader_parameter("wag", {"tetra": 7.0, "bala": 4.5}.get(kind, 4.0))
	mi.set_instance_shader_parameter("size", k["len"] * 0.5)
	add_child(mi)
	var pos := _free_point(kind)
	var f := {"kind": kind, "node": mi, "pos": pos, "vel": Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5).normalized() * k["speed"] * 0.5,
			"goal": _free_point(kind), "goal_t": rng.randf_range(4.0, 10.0), "pause_t": 0.0, "alarm": 0.0, "flee": Vector3.ZERO,
			"speed_k": rng.randf_range(0.8, 1.15), "school": 0}
	mi.global_position = pos
	fish.append(f)


## A random point in the kind's depth band, clear of every moss ball.
func _free_point(kind: String) -> Vector3:
	var band: Array = KINDS[kind]["band"]
	for tries in 40:
		var p := Vector3(rng.randf_range(tank_min.x, tank_max.x), lerpf(tank_min.y, tank_max.y, rng.randf_range(band[0], band[1])), rng.randf_range(tank_min.z, tank_max.z))
		if _clear(p):
			return p
	return Vector3((tank_min.x + tank_max.x) * 0.5, tank_max.y - 5.0, tank_min.z + 5.0)


func _clear(p: Vector3) -> bool:
	for o in obstacles:
		if p.distance_to(o[0]) < o[1]:
			return false
	return true


func _physics_process(dt: float) -> void:
	step(dt, _gill_point())


## Where Gill is (for alerts and scattering), or INF when he is not in the water.
func _gill_point() -> Vector3:
	var g := Game.inst
	if g == null or g.player == null or not g.player.is_inside_tree():
		return Vector3.INF
	# In the aquarium experiences only the Swim Mode swimmer is in the water (docs/AQUARIUM.md).
	if g.presentation != null and g.presentation.active():
		return g.presentation.gill_point()
	return g.player.body_center()


## One simulation step (public so tests can run it directly).
func step(dt: float, gill: Vector3) -> void:
	if dt <= 0.0:
		return
	# Each schooling kind's school (the tetras, the bala sharks): its centre and heading.
	var schools := {}
	for f in fish:
		if KINDS[f["kind"]]["school"]:
			var sch: Array = schools.get(f["kind"], [Vector3.ZERO, Vector3.ZERO, 0])
			sch[0] += f["pos"]
			sch[1] += f["vel"]
			sch[2] += 1
			schools[f["kind"]] = sch
	for kind in schools:
		var sch: Array = schools[kind]
		sch[0] /= sch[2]
		sch[1] /= sch[2]
	for f in fish:
		var sch: Array = schools.get(f["kind"], [Vector3.ZERO, Vector3.ZERO, 0])
		_steer(f, dt, gill, sch[0], sch[1], sch[2])


func _steer(f: Dictionary, dt: float, gill: Vector3, sc: Vector3, sv: Vector3, sn: int) -> void:
	var k: Dictionary = KINDS[f["kind"]]
	var pos: Vector3 = f["pos"]
	var vel: Vector3 = f["vel"]
	var speed: float = k["speed"] * f["speed_k"]
	f["goal_t"] -= dt
	if f["goal_t"] <= 0.0 or pos.distance_to(f["goal"]) < 4.0 + k["len"]:
		f["goal"] = _free_point(f["kind"])
		f["goal_t"] = rng.randf_range(5.0, 12.0)
		# Now and then a pause (hanging in the water, or a cory resting on the gravel).
		if rng.randf() < (0.45 if f["kind"] == "cory" else 0.18):
			f["pause_t"] = rng.randf_range(1.0, 3.5)
	var want: Vector3 = ((f["goal"] as Vector3) - pos).normalized() * speed
	if f["pause_t"] > 0.0:
		f["pause_t"] -= dt
		want *= 0.12
	# Schooling (tetras, bala sharks): toward the school, along its heading, not too close.
	if k["school"] and sn > 1 and f["alarm"] < 0.5:
		want = want * 0.45 + (sc - pos).limit_length(1.0) * speed * 0.35 + sv.limit_length(speed) * 0.35
		for o in fish:
			if o != f and o["kind"] == f["kind"]:
				var d: Vector3 = pos - (o["pos"] as Vector3)
				var gap: float = k["len"] * 1.3
				if d.length() < gap and d.length() > 0.001:
					want += d.normalized() * speed * (gap - d.length()) / gap
	# Gill: noticed within ~7 m, fled from within ~2.5 m (a bump sends them darting off).
	if gill != Vector3.INF:
		var to_g := gill - pos
		var dg := to_g.length()
		var react: float = k["timid"] * reactivity
		var body_len: float = k["len"]
		if dg < (2.5 + body_len * 0.7) * (0.6 + react * 0.5):
			f["alarm"] = 1.0
			f["flee"] = (-to_g).normalized() * speed * (1.8 + react)
			if k["school"]:
				for o in fish:
					if o["kind"] == f["kind"] and (o["pos"] as Vector3).distance_to(pos) < body_len * 3.0:
						o["alarm"] = maxf(o["alarm"], 0.8)
						o["flee"] = ((o["pos"] as Vector3) - gill).normalized() * speed * 2.2
		elif dg < 7.0 + body_len * 1.5 and f["kind"] == "gourami" and f["alarm"] <= 0.0:
			# Curious: drifts a little toward him, never close.
			want = want * 0.6 + to_g.normalized() * speed * 0.35
	if f["alarm"] > 0.0:
		f["alarm"] = maxf(0.0, f["alarm"] - dt * 0.4)
		want = want.lerp(f["flee"], clampf(f["alarm"] * 1.5, 0.0, 1.0))
	# Keep off the moss balls, the glass and the gravel.
	for o in obstacles:
		var d2: Vector3 = pos - (o[0] as Vector3)
		var over: float = (o[1] as float) + 3.0 - d2.length()
		if over > 0.0:
			want += d2.normalized() * speed * over * 0.6
	for ax in 3:
		var lo: float = tank_min[ax]
		var hi: float = tank_max[ax]
		if pos[ax] < lo + 6.0:
			want[ax] += speed * (lo + 6.0 - pos[ax]) * 0.3
		elif pos[ax] > hi - 6.0:
			want[ax] -= speed * (pos[ax] - hi + 6.0) * 0.3
	var max_speed := speed * (2.6 if f["alarm"] > 0.3 else 1.0)
	want = want.limit_length(max_speed)
	# Turn-rate limited, with a little inertia (never an instant about-face).
	var turn: float = k["turn"] * (2.2 if f["alarm"] > 0.3 else 1.0)
	vel = vel.lerp(want, clampf(turn * dt, 0.0, 1.0))
	pos += vel * dt
	# Never through a moss ball or out of the tank, whatever the steering did.
	for o in obstacles:
		var d3: Vector3 = pos - (o[0] as Vector3)
		var r: float = o[1]
		if d3.length() < r:
			pos = (o[0] as Vector3) + d3.normalized() * r
	pos = pos.clamp(tank_min, tank_max)
	f["pos"] = pos
	f["vel"] = vel
	var mi: MeshInstance3D = f["node"]
	var fwd := vel.normalized() if vel.length() > 0.05 else -mi.global_basis.z
	# Level-ish: pitch follows climbing and diving a little, never rolled.
	var flat := Vector3(fwd.x, 0, fwd.z)
	if flat.length() < 0.05:
		flat = -mi.global_basis.z
	var look := flat.normalized().lerp(fwd, 0.5).normalized()
	var b := Basis.looking_at(look, Vector3.UP)
	var ob := mi.global_basis.orthonormalized().slerp(b, clampf(dt * 5.0, 0.0, 1.0))
	mi.global_transform = Transform3D(ob.scaled_local(Vector3.ONE * display_scale), pos)
	mi.set_instance_shader_parameter("swim", clampf(vel.length() / maxf(0.1, speed), 0.2, 2.5))


## Nearest fish distance to `p` (tests).
func nearest(p: Vector3) -> float:
	var best := INF
	for f in fish:
		best = minf(best, p.distance_to(f["pos"]))
	return best


## The nearest fish's position to `p`, or INF (Swim Mode: Gill notices fish that come close).
func nearest_point(p: Vector3) -> Vector3:
	var best := INF
	var at := Vector3.INF
	for f in fish:
		var d := p.distance_squared_to(f["pos"])
		if d < best:
			best = d
			at = f["pos"]
	return at


# --- Meshes --------------------------------------------------------------------------------

## A stylised fish of the kind, head toward -Z, body length `len` along Z, built once per kind.
## Vertex colour carries the pattern; UV.x (0 head .. 1 tail) drives the swimming wave.
func _mesh_for(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var k: Dictionary = KINDS[kind]
	var cols: Array = k["col"]
	var L: float = k["len"] * 0.5
	var h_scale := 1.0
	var w_scale := 0.55
	match kind:
		"gourami":
			h_scale = 1.25
			w_scale = 0.4
		"angel":
			h_scale = 1.9
			w_scale = 0.3
		"cory":
			h_scale = 0.85
			w_scale = 0.75
		"bala":
			h_scale = 0.95
			w_scale = 0.45
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 12
	var sides := 10
	var ring := func(u: float) -> float:
		return sin(PI * clampf(u * 0.92 + 0.04, 0.0, 1.0)) * (1.0 - 0.55 * u)
	for i in rings + 1:
		var u := float(i) / rings
		var z := lerpf(-L, L, u)
		var r: float = ring.call(u) * L * 0.34
		for s in sides:
			var a := TAU * s / sides
			var y := sin(a) * r * h_scale
			var x := cos(a) * r * w_scale
			var c: Color = cols[0]
			match kind:
				"tetra":
					# A bright stripe along the side over a red lower rear.
					if absf(sin(a)) < 0.35 and u < 0.8:
						c = cols[0]
					elif sin(a) < -0.2 and u > 0.45:
						c = cols[1]
					else:
						c = cols[2].darkened(0.25)
				"angel":
					c = cols[1] if fmod(u * 3.2, 1.0) < 0.28 else cols[0]
				"gourami":
					c = cols[0].lerp(cols[1], 0.5 + 0.5 * sin(a + u * 5.0)) if sin(a) > -0.3 else cols[2]
				"bala":
					# Silver, a darker steel back and a faint lateral line.
					c = cols[0].darkened(0.3).lerp(Color(0.45, 0.52, 0.6), 0.4) if sin(a) > 0.55 else cols[0]
					if absf(sin(a)) < 0.12 and u > 0.15 and u < 0.9:
						c = cols[0].darkened(0.18)
					if sin(a) < -0.6:
						c = cols[0].lightened(0.15)
				"cory":
					c = cols[1] if (fmod(u * 7.0 + a, 1.3) < 0.3 and sin(a) > 0.0) else (cols[2] if sin(a) < -0.4 else cols[0])
			st.set_color(c)
			st.set_uv(Vector2(u, 0))
			st.add_vertex(Vector3(x, y, z))
	for i in rings:
		for s in sides:
			var a0 := i * sides + s
			var b0 := i * sides + (s + 1) % sides
			for q in [a0, a0 + sides, b0, b0, a0 + sides, b0 + sides]:
				st.add_index(q)
	var base := (rings + 1) * sides
	# Tail fin (a forked fan), dorsal fin, and for the angel two long trailing fins.
	var fin_col: Color = cols[2] if kind != "tetra" else Color(0.9, 0.95, 1.0, 1.0)
	var tail := Vector3(0, 0, L)
	var tail_h := L * (0.5 if kind != "angel" else 0.9)
	# (Bala sharks' fins are yellowish with black edges: their outer points are black.)
	var edge_col: Color = cols[1] if kind == "bala" else fin_col
	var tri := func(p0: Vector3, p1: Vector3, p2: Vector3, u0: float, u1: float, u2: float) -> void:
		for q in [[p0, u0, fin_col], [p1, u1, edge_col], [p2, u2, fin_col]]:
			st.set_color(q[2])
			st.set_uv(Vector2(q[1], 0))
			st.add_vertex(q[0])
		st.add_index(base)
		st.add_index(base + 1)
		st.add_index(base + 2)
		st.add_index(base)
		st.add_index(base + 2)
		st.add_index(base + 1)
		base += 3
	tri.call(tail - Vector3(0, 0, L * 0.12), tail + Vector3(0, tail_h, L * 0.55), tail + Vector3(0, 0, L * 0.3), 0.95, 1.2, 1.1)
	tri.call(tail - Vector3(0, 0, L * 0.12), tail + Vector3(0, -tail_h, L * 0.55), tail + Vector3(0, 0, L * 0.3), 0.95, 1.2, 1.1)
	var dors_h := L * (0.25 if kind != "angel" else 0.95)
	# (Rooted a little inside the back, so it never floats off a slim body.)
	var dy := L * (0.2 if kind == "bala" else 0.3) * h_scale
	tri.call(Vector3(0, dy, -L * 0.1), Vector3(0, dy + dors_h * (1.5 if kind == "bala" else 1.0), L * 0.35), Vector3(0, dy * 0.85, L * 0.45), 0.45, 0.7, 0.72)
	if kind == "bala":
		# Pelvic and anal fins under the body.
		tri.call(Vector3(0, -L * 0.18 * h_scale, -L * 0.2), Vector3(0, -L * 0.18 * h_scale - L * 0.2, L * 0.02), Vector3(0, -L * 0.16 * h_scale, L * 0.05), 0.35, 0.45, 0.47)
		tri.call(Vector3(0, -L * 0.12 * h_scale, L * 0.3), Vector3(0, -L * 0.12 * h_scale - L * 0.17, L * 0.5), Vector3(0, -L * 0.1 * h_scale, L * 0.55), 0.62, 0.74, 0.76)
	if kind == "angel":
		tri.call(Vector3(0, -L * 0.3 * h_scale, -L * 0.05), Vector3(0, -L * 0.3 * h_scale - dors_h, L * 0.4), Vector3(0, -L * 0.25 * h_scale, L * 0.45), 0.45, 0.72, 0.72)
	# Eyes: two dark discs.
	for side in [-1.0, 1.0]:
		var e := Vector3(side * L * 0.12 * w_scale * 1.9, L * 0.06, -L * 0.62)
		for s in 6:
			var a0 := TAU * s / 6.0
			var a1 := TAU * (s + 1) / 6.0
			var er := L * 0.07
			for q in [e, e + Vector3(0, cos(a0), sin(a0)) * er, e + Vector3(0, cos(a1), sin(a1)) * er]:
				st.set_color(Color(0.05, 0.05, 0.07))
				st.set_uv(Vector2(0.1, 0))
				st.add_vertex(q)
			st.add_index(base)
			st.add_index(base + 1)
			st.add_index(base + 2)
			st.add_index(base)
			st.add_index(base + 2)
			st.add_index(base + 1)
			base += 3
	st.generate_normals()
	var m := st.commit()
	_meshes[kind] = m
	return m
