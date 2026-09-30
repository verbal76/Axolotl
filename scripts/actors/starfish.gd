class_name Starfish
extends Node3D
## A red starfish (docs/SKILL_TREE.md): the skill tree's currency, one of 30 authored in
## StarfishTable. Clearly red with a soft local glow (the Motes' own glow billboard, tinted), lying on
## the surface it was put on. Touched (Game._check_starfish: his body within REACH, on the ground or
## in the air, no button) it is collected: a small burst, its own sound, and it is gone for good.
##
## Its materials reuse set-ups the world already draws (the Mote core's StandardMaterial3D features
## and glow_billboard.gdshader), so the first one seen compiles no new shader.

const REACH := 0.9
const GLOW_SHADER := preload("res://shaders/glow_billboard.gdshader")
const RED := Color(0.92, 0.1, 0.08)
const RED_GLOW := Color(1.0, 0.18, 0.12)

var id := ""
var ball: MossBall
var up := Vector3.UP
## Where it rests (the surface point) and how it got there.
var rest := Vector3.ZERO
var relocated := false
var collected := false
var _t := 0.0
var _gone_t := -1.0
var _body: MeshInstance3D
var _halo: MeshInstance3D
static var _mesh: ArrayMesh
static var _mat: StandardMaterial3D


func setup(p_ball: MossBall, p_id: String, pos: Vector3) -> void:
	ball = p_ball
	id = p_id
	rest = pos
	up = ball.up_at(pos)


func _ready() -> void:
	name = "Starfish_" + id.replace(".", "_")
	_body = MeshInstance3D.new()
	_body.mesh = star_mesh()
	_body.material_override = material()
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_body)
	_halo = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.25, 1.25)
	_halo.mesh = q
	var hm := ShaderMaterial.new()
	hm.shader = GLOW_SHADER
	hm.set_shader_parameter("color", RED_GLOW)
	hm.set_shader_parameter("strength", 0.42)
	_halo.material_override = hm
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo.position = Vector3(0, 0.12, 0)
	add_child(_halo)
	for mi in [_body, _halo]:
		mi.visibility_range_end = 60.0
	_place()


func _place() -> void:
	up = ball.up_at(rest)
	var fr := MossBall.frame_at(up, float(hash(id) % 360))
	global_transform = Transform3D(fr, rest + up * 0.05)


## The shared starfish material: the Mote core's set-up (albedo + emission), in red.
static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = RED
		_mat.emission_enabled = true
		_mat.emission = RED_GLOW
		_mat.emission_energy_multiplier = 1.6
	return _mat


## Five plump tapering arms round a raised middle, about 0.45 m across (normals, UVs and tangents,
## as the primitive meshes the world already draws).
static func star_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arms := 5
	var seg := 40
	var rings := 4
	var outline: Array[Vector2] = []
	for k in seg:
		var a := TAU * k / seg
		# Arm lobes: the radius swells toward each arm's tip and pinches between arms.
		var lobe := pow(absf(cos(a * arms * 0.5)), 1.6)
		outline.append(Vector2(cos(a), sin(a)) * lerpf(0.085, 0.23, lobe))
	# Rings from the rim (h 0) to the domed middle; each arm is thicker at its root.
	var verts: Array[Vector3] = []
	for r in rings + 1:
		var f := float(r) / rings
		for k in seg:
			var o: Vector2 = outline[k] * (1.0 - f * 0.92)
			var h := 0.012 + 0.07 * sin(f * PI * 0.5) * (0.6 + 0.4 * (1.0 - o.length() / 0.23))
			verts.append(Vector3(o.x, h, o.y))
	var top := Vector3(0, 0.085, 0)
	for r in rings:
		for k in seg:
			var a0 := r * seg + k
			var a1 := r * seg + (k + 1) % seg
			var b0 := (r + 1) * seg + k
			var b1 := (r + 1) * seg + (k + 1) % seg
			for i in [a0, b0, a1, a1, b0, b1]:
				var v: Vector3 = verts[i]
				st.set_uv(Vector2(float(i % seg) / seg, float(i / seg) / rings))
				st.add_vertex(v)
	for k in seg:
		var i0 := rings * seg + k
		var i1 := rings * seg + (k + 1) % seg
		for v in [verts[i0], top, verts[i1]]:
			st.set_uv(Vector2(0.5, 1.0))
			st.add_vertex(v)
	st.generate_normals()
	st.generate_tangents()
	_mesh = st.commit()
	return _mesh


func _process(dt: float) -> void:
	_t += dt
	if _gone_t >= 0.0:
		# Collected: a quick lift and pop, then gone.
		_gone_t += dt
		var k := clampf(_gone_t / 0.35, 0.0, 1.0)
		scale = Vector3.ONE * (1.0 + 0.9 * sin(k * PI * 0.5)) * (1.0 - k * k)
		position += up * dt * 1.2
		(_halo.material_override as ShaderMaterial).set_shader_parameter("strength", 0.42 + 1.4 * (1.0 - k))
		if k >= 1.0:
			queue_free()
		return
	# A slow breath of its glow (no motion that could read as a marker).
	var pulse := 0.36 + 0.08 * sin(_t * 2.1 + float(hash(id) % 100) * 0.1)
	(_halo.material_override as ShaderMaterial).set_shader_parameter("strength", pulse)


## The point his body must come within REACH of.
func pick_point() -> Vector3:
	return rest + up * 0.12


## The pickup burst: red and gold motes of light thrown out in a small sphere. Laid out on a golden
## spiral, not rolled: WaterFX's own random sequence also decides where his running stirs the water
## (WaterFX.trail), which moves Motes and parasites, so a pickup must not draw from it (the seeded
## playthroughs stay identical whether or not the bot happens to touch a starfish).
func collect_fx() -> void:
	collected = true
	_gone_t = 0.0
	var fx := WaterFX.inst
	var c := pick_point()
	var n := 30
	for i in n:
		var y := 1.0 - 2.0 * (i + 0.5) / n
		var r := sqrt(maxf(0.0, 1.0 - y * y))
		var a := i * 2.39996
		var d := (Vector3(cos(a) * r, y, sin(a) * r) + up * 0.5).normalized()
		var gold := i % 4 == 0
		fx._spawn_puff(c, d * (1.1 if gold else 1.7) * (0.7 + 0.3 * float(i % 3) / 2.0), 0.6 if gold else 0.9, 0.05 if gold else 0.07,
				Color(1.0, 0.85, 0.6, 0.9) if gold else Color(1.0, 0.3, 0.22, 0.95), 1.5)


# --- Placement (StarfishTable spots, validated with Treasure Hunt's checks) ----------------------

## The surface under a table entry: [position, collider] or [] when nothing is there.
static func probe(b: MossBall, dir: Vector3, alt: float) -> Array:
	var space := b.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(b.surface_point(dir, alt + 0.9), b.surface_point(dir, alt - 1.4), TreasureHunt.SOLID_MASK)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return []
	return [hit["position"], hit["collider"]]


## Things a starfish keeps CLEAR of: every Mote's anchor, bloom, Tier-2 shrine and cave reward on
## the ball (world positions).
static func keep_clear_points(b: MossBall) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var space := b.get_world_3d().direct_space_state
	for m in b.motes:
		if (m as Mote).state != "init":
			out.append((m as Mote).anchor)
		else:
			# (Where the Mote will anchor on its first frame: the same probe it makes.)
			var top := b.surface_point(m.home_dir(), m.h_hint + 3.0)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, b.global_position, 1 | 2 | LevelBuilder.CLIMB_LAYER))
			out.append(hit["position"] if not hit.is_empty() else b.surface_point(m.home_dir()))
	for bl in b.blooms:
		out.append((bl as Node3D).global_position)
	for s in b.shrines:
		out.append((s as Tier2Shrine).touch_point())
	for u in b.upgrades:
		out.append((u as Node3D).global_position)
	return out


static func clearance(p: Vector3, keep: Array[Vector3]) -> float:
	var d := INF
	for k in keep:
		d = minf(d, p.distance_to(k))
	return d


## Whether a starfish may rest at `p` (Treasure Hunt's validators for its kind, at SCALE, and CLEAR
## of Motes, blooms, shrines and cave rewards). `cave` is the cave's bot hint for a cave floor.
static func spot_valid(b: MossBall, p: Vector3, kind: String, keep: Array[Vector3], clear := StarfishTable.CLEAR) -> bool:
	if clearance(p, keep) < clear:
		return false
	return TreasureHunt.target_ok(b, {"pos": [p.x, p.y, p.z], "scale": StarfishTable.SCALE, "spot": kind})


## Where a table entry's starfish rests: its authored spot if valid, else the nearest valid point on
## the same feature (the same collider) within 3 m, keeping its id. {"pos", "relocated", "valid"}.
static func resolve(b: MossBall, e: Dictionary, keep: Array[Vector3], clear := StarfishTable.CLEAR) -> Dictionary:
	var ll: Array = e["ll"]
	var dir := MossBall.dir_ll(float(ll[0]), float(ll[1]))
	var alt := float(e["alt"])
	var kind := str(e["kind"])
	var hit := probe(b, dir, alt)
	if hit.is_empty():
		return {"pos": b.surface_point(dir, alt), "relocated": false, "valid": false}
	var p0: Vector3 = hit[0]
	if spot_valid(b, p0, kind, keep, clear):
		return {"pos": p0, "relocated": false, "valid": true}
	var up := b.up_at(p0)
	var fr := MossBall.frame_at(up, 0.0)
	var h0 := b.altitude(p0)
	for ring in range(1, 11):
		var r := ring * 0.3
		var best := Vector3.INF
		for k in 16:
			var o := p0 + fr.z.rotated(up, TAU * k / 16.0) * r
			var h := probe(b, (o - b.global_position).normalized(), h0)
			if h.is_empty() or h[1] != hit[1]:
				continue
			if absf(b.altitude(h[0]) - h0) > 0.6:
				continue
			if spot_valid(b, h[0], kind, keep, clear) and (best == Vector3.INF or (h[0] as Vector3).distance_to(p0) < best.distance_to(p0)):
				best = h[0]
		if best != Vector3.INF:
			return {"pos": best, "relocated": true, "valid": true}
	return {"pos": p0, "relocated": false, "valid": false}
