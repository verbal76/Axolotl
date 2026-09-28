class_name CanopySnail
extends Critter
## A snail that lives up on leaves and shelves (docs/ECOSYSTEM.md): it creeps slowly back and forth
## along its leaf, eye stalks out. When the axolotl lands or moves close it pulls into its shell
## and stays tucked in a while. Harmless; life for the high routes.

const TUCK_R := 2.3
const TUCK_TIME := 5.0
const SPEED := 0.12

var a := Vector3.ZERO
var b := Vector3.ZERO
var t := 0.5
var dir := 1.0
var tuck := 0.0
var tuck_t := 0.0
var _pause := 0.0
var _body: Node3D
var _shell: MeshInstance3D
var _ray_t := 0.0
var _surface := Vector3.ZERO


## Creeps between `p0` and `p1` (points on the top of one leaf or shelf).
func place(p_ball: MossBall, p0: Vector3, p1: Vector3, seed_v: int) -> void:
	setup(p_ball, "snail", "leaves and shelves", seed_v)
	seen_radius = 4.0
	p_ball.add_child(self)
	a = p0
	b = p1
	t = rng.randf()
	_build()
	global_position = a.lerp(b, t)


func late_place() -> void:
	_settle()


func _build() -> void:
	# Two meshes: the soft body with its eye stalks (it shrinks in when tucked), and the shell.
	_body = Node3D.new()
	add_child(_body)
	var skin := Color(0.72, 0.68, 0.55)
	var parts := [[Critter.sphere(0.07, 8), skin, Critter.xf(Vector3(0, 0.035, -0.02), Vector3(0.9, 0.5, 2.6))]]
	for side in [-1.0, 1.0]:
		parts.append([Critter.sphere(0.012, 5), skin, Critter.xf(Vector3(side * 0.03, 0.09, -0.19), Vector3(1.0, 5.0, 1.0))])
		parts.append([Critter.sphere(0.016, 5), Color(0.1, 0.08, 0.06), Critter.xf(Vector3(side * 0.03, 0.15, -0.19))])
	Critter.part(Critter.merge(parts), Critter.vc_mat(), _body)
	_shell = Critter.part(_shell_mesh(), Critter.mat(Color(0.55, 0.3, 0.2)), self, Vector3(0, 0.1, 0.04))


## A coiled shell: a flattened spiral of shrinking spheres merged into one mesh.
static func _shell_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sph := SphereMesh.new()
	sph.radial_segments = 8
	sph.rings = 5
	for k in 9:
		var ang := k * 0.75
		var r := 0.085 * pow(0.86, k)
		var c := Vector3(0, cos(ang) * (0.09 - r) * 0.8, sin(ang) * (0.09 - r) * 0.8)
		sph.radius = r
		sph.height = r * 2.0
		var arr := sph.get_mesh_arrays()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for i in idx:
			st.add_vertex(c + v[i] * Vector3(0.75, 1.0, 1.0))
	st.generate_normals()
	return st.commit()


func _settle() -> void:
	var p := a.lerp(b, t)
	var hit := ground_under(p, LEAF_MASK, 0.4, 0.8)
	_surface = (hit["position"] as Vector3) if hit else p
	var up := ball.up_at(_surface)
	var fwd := (b - a) * dir
	fwd = (fwd - up * fwd.dot(up)).normalized()
	# Drawn at twice life size so it reads on a leaf at phone scale.
	global_transform = Transform3D(Basis(fwd.cross(up).normalized(), up, -fwd).orthonormalized().scaled(Vector3.ONE * 2.0), _surface)


func tick(dt: float) -> void:
	var p := player()
	if player_here() and p.global_position.distance_to(global_position) < TUCK_R:
		if tuck_t <= 0.0:
			tuck_t = TUCK_TIME
		tuck_t = maxf(tuck_t, 1.0)
	tuck_t = maxf(0.0, tuck_t - dt)
	tuck = move_toward(tuck, 1.0 if tuck_t > 0.0 else 0.0, dt * (4.0 if tuck_t > 0.0 else 0.6))
	if tuck < 0.05:
		_pause -= dt
		if _pause <= 0.0:
			var len := maxf(a.distance_to(b), 0.1)
			t += dir * SPEED * dt / len
			if t > 1.0 or t < 0.0:
				t = clampf(t, 0.0, 1.0)
				dir = -dir
				_pause = rng.randf_range(1.0, 3.0)
			_ray_t -= dt
			if _ray_t <= 0.0:
				_ray_t = 0.3
				_settle()
			else:
				global_position = a.lerp(b, t) + (_surface - a.lerp(b, t)).project(ball.up_at(_surface))
	_body.scale = Vector3.ONE * lerpf(1.0, 0.25, tuck)
	_body.position = Vector3(0, 0, 0.06 * tuck)


func is_hidden() -> bool:
	return false
