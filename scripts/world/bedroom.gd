class_name Bedroom
extends Node3D
## The bedroom round the axolotl's aquarium (docs/AQUARIUM.md): a lived-in late-1980s / early-1990s kid's
## room at dusk, a little messy and warm, with the aquarium on the dresser as the focal point of the
## room view: a wood-grain CRT on a cart with a game console at its left, the bed with its bookcase
## headboard and bedside lamp at its right, a shelf of keepsakes above, the desk, bookshelf and window
## round the rest of the room. Original, generic designs only (no brands, characters or logos).
##
## Built from bevelled boxes, smooth cylinders, blobs and thick cloth surfaces merged into one mesh per
## material (seven: printed/matte, glossy, glowing, wood, wallpaper, comforter, fabric), so the room is
## a handful of draw calls. Every printed thing samples one atlas (tools/gen_room.py). Vertex colours
## carry a cheap baked occlusion (darker near the floor, in corners and under furniture). The room's
## materials ignore the world's water-tinted ambient light and use their own warm hemisphere ambient,
## so the room reads as a lamp-lit bedroom however murky the tank is. Everything is on
## Aquarium.ROOM_LAYER; the room's lamps (here and in Aquarium._build_light) only light that layer.
##
## Units are millimetres (the tank is 580 wide). The room runs X -1600..1600, Z -330 (the wall
## behind the tank) .. 3100 (the door), floor FLOOR_Y, ceiling FLOOR_Y + 2300.

const X0 := -1600.0
const X1 := 1600.0
const Z0 := -330.0
const Z1 := 3100.0
const TEX := "res://assets/textures/room/"
const ATLAS_PX := Vector2(2048, 1024)
## Atlas regions in pixels (mirrors ATLAS in tools/gen_room.py).
const ATLAS := {
	"white": Rect2(1248, 888, 64, 64),
	"poster_space": Rect2(0, 0, 400, 540),
	"poster_shapes": Rect2(408, 0, 400, 540),
	"poster_sunset": Rect2(816, 0, 400, 540),
	"window": Rect2(1224, 0, 440, 380),
	"crt": Rect2(1672, 0, 368, 276),
	"border": Rect2(1224, 388, 440, 64),
	"cassette": Rect2(1224, 460, 440, 80),
	"clock": Rect2(1672, 284, 176, 64),
	"stickers": Rect2(1672, 356, 352, 176),
	"note_paper": Rect2(0, 552, 224, 280),
	"homework": Rect2(232, 552, 224, 290),
	"calendar": Rect2(464, 552, 224, 300),
	"drawing": Rect2(0, 852, 224, 168),
	"notebook": Rect2(232, 852, 224, 168),
	"cork": Rect2(464, 860, 224, 160),
	"comics": Rect2(696, 552, 768, 176),
	"magazines": Rect2(696, 736, 544, 184),
	"carts": Rect2(1248, 736, 192, 144),
	"spines": Rect2(1472, 552, 560, 220),
	"rug": Rect2(1472, 780, 560, 236),
	"boardgame": Rect2(696, 928, 200, 90),
	"pennant": Rect2(904, 928, 300, 90),
	"tv_bezel": Rect2(1320, 888, 140, 128),
}
const UV4 := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
## A box's faces: corner indices (counter-clockwise from outside), normal, UV plane (xy, zy, xz).
const BOX_FACES := [[4, 5, 6, 7, Vector3.BACK, 0], [1, 0, 3, 2, Vector3.FORWARD, 0], [5, 1, 2, 6, Vector3.RIGHT, 1],
		[0, 4, 7, 3, Vector3.LEFT, 1], [7, 6, 2, 3, Vector3.UP, 2], [0, 1, 5, 4, Vector3.DOWN, 2]]

## Lit room surfaces: albedo from a texture times the vertex colour (which also carries the baked
## occlusion), no world ambient (it is tinted by the water), a warm hemisphere ambient of its own.
const LIT_SHADER := """
shader_type spatial;
render_mode ambient_light_disabled, fog_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float rough = 0.85;
uniform float spec = 0.35;
uniform vec3 amb_up : source_color = vec3(0.60, 0.50, 0.42);
uniform vec3 amb_down : source_color = vec3(0.28, 0.21, 0.17);
uniform float amb = 1.0;
// The room's own lamps (desk, bedside, TV), lit here rather than as scene lights: a scene light's
// layer mask is only tested per pixel on the Mobile renderer, so real lights this size would be
// evaluated over the whole tank too.
uniform vec3 lamp_pos[3];
uniform vec3 lamp_col[3];
uniform float lamp_range[3];
void fragment() {
	vec3 a = texture(tex, UV).rgb * COLOR.rgb;
	ALBEDO = a;
	ROUGHNESS = rough;
	SPECULAR = spec;
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 lit = mix(amb_down, amb_up, wn.y * 0.5 + 0.5) * amb;
	for (int k = 0; k < 3; k++) {
		vec3 l = lamp_pos[k] - wp;
		float d = length(l);
		float att = pow(clamp(1.0 - d / max(lamp_range[k], 1.0), 0.0, 1.0), 1.2);
		lit += lamp_col[k] * att * max(dot(wn, l / max(d, 0.001)), 0.0);
	}
	EMISSION = a * lit;
}
"""
## Lamps, screens, the window's dusk view and indicator lights: their own colour, unlit.
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float boost = 1.0;
void fragment() {
	ALBEDO = texture(tex, UV).rgb * COLOR.rgb * boost;
}
"""


## One material's merged geometry (non-indexed triangles).
class Buf:
	var i := PackedInt32Array()
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var t := PackedVector2Array()


var floor_y := -825.0
var y1 := 1475.0
var _mats := {}
var _sts := {}
var _layer := 2
var _r := RandomNumberGenerator.new()
## Baked occlusion mode for what is being built: 0 furniture and props, 1 floor, 2 walls/ceiling,
## -1 none.
var _ao_mode := 0
## Footprints (x, z) of furniture, which darken the floor round and under them.
var _feet: Array[Rect2] = []
var _regions := {}
## Where the room view looks from and at (Aquarium experiences).
var view_pos := Vector3(330, 200, 1250)
var view_look := Vector3(-10, -40, 0)
## Total vertices built (for the performance notes in docs/AQUARIUM.md).
var vertex_count := 0
var _tmin := Vector3.ZERO
var _tmax := Vector3.ZERO


## Builds the room, complete, on the calling thread: its lamps, then its geometry merged into one
## mesh per material.
func build(p_floor_y: float, layer: int, tank_min: Vector3, tank_max: Vector3) -> void:
	floor_y = p_floor_y
	y1 = floor_y + 2300.0
	_layer = layer
	_r.seed = 1990
	_tmin = tank_min
	_tmax = tank_max
	name = "Bedroom"
	_lights()
	_generate()
	_commit()
	_apply_lamps()


## All the geometry (pure data: no nodes).
func _generate() -> void:
	_tank_corner(_tmin, _tmax)
	_dresser_things(_tmin, _tmax)
	_wall_shelf()
	_tv_corner()
	_bed()
	_bookshelf()
	_desk()
	_front_of_room()
	_floor_things()
	_walls_things()
	_shell()


# --- Materials and merging ------------------------------------------------------------------

func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GLOW_SHADER if key == "glow" else LIT_SHADER
	m.shader = sh
	var tex := "atlas"
	match key:
		"gloss":
			m.set_shader_parameter("rough", 0.3)
			m.set_shader_parameter("spec", 0.6)
		"wood":
			tex = "wood"
			m.set_shader_parameter("rough", 0.55)
			m.set_shader_parameter("spec", 0.45)
		"wallpaper":
			tex = "wallpaper"
			m.set_shader_parameter("rough", 0.95)
			m.set_shader_parameter("spec", 0.2)
		"blanket":
			tex = "blanket"
			m.set_shader_parameter("rough", 1.0)
			m.set_shader_parameter("spec", 0.12)
		"fabric":
			tex = "fabric"
			m.set_shader_parameter("rough", 1.0)
			m.set_shader_parameter("spec", 0.12)
	m.set_shader_parameter("tex", load(TEX + tex + ".png"))
	_mats[key] = m
	return m


## The buffer merging everything drawn with material `key` ("vc" and "atlas" share one).
func _st(key: String) -> Buf:
	if key == "vc":
		key = "atlas"
	if not _sts.has(key):
		_sts[key] = Buf.new()
	return _sts[key]


func _commit() -> void:
	vertex_count = 0
	for key in _sts:
		var b: Buf = _sts[key]
		if b.v.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = b.v
		arr[Mesh.ARRAY_NORMAL] = b.n
		arr[Mesh.ARRAY_COLOR] = b.c
		arr[Mesh.ARRAY_TEX_UV] = b.t
		arr[Mesh.ARRAY_INDEX] = b.i
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.name = "Room_" + key
		mi.mesh = am
		mi.material_override = _mat(key)
		mi.layers = 1 << (_layer - 1)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		vertex_count += b.v.size()
	_sts.clear()


func _region(reg: String) -> Rect2:
	var r: Rect2 = ATLAS[reg]
	# (Half a texel in, so filtering never reaches the neighbours.)
	return Rect2((r.position + Vector2(1, 1)) / ATLAS_PX, (r.size - Vector2(2, 2)) / ATLAS_PX)


func _rect_dist(r: Rect2, p: Vector2) -> float:
	var c := r.get_center()
	var q := (p - c).abs() - r.size * 0.5
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)


## The baked occlusion at world point p.
func _occ(p: Vector3) -> float:
	var dx := minf(p.x - X0, X1 - p.x)
	var dz := minf(p.z - Z0, Z1 - p.z)
	match _ao_mode:
		0:
			return lerpf(0.6, 1.0, smoothstep(0.0, 240.0, p.y - floor_y)) * lerpf(0.8, 1.0, smoothstep(0.0, 260.0, minf(dx, dz)))
		1:
			var k := lerpf(0.55, 1.0, smoothstep(0.0, 380.0, minf(dx, dz)))
			for f in _feet:
				k *= lerpf(0.45, 1.0, smoothstep(-80.0, 240.0, _rect_dist(f, Vector2(p.x, p.z))))
			return k
		2:
			var dy := minf(p.y - floor_y, y1 - p.y)
			# (On a wall: the distance to the other wall of the nearer corner; on the ceiling: to a wall.)
			var dc := maxf(dx, dz) if minf(dx, dz) < 30.0 and p.y < y1 - 30.0 else minf(dx, dz)
			return lerpf(0.62, 1.0, smoothstep(0.0, 420.0, dy)) * lerpf(0.66, 1.0, smoothstep(0.0, 520.0, dc))
	return 1.0


## Triangles (3 points) or a quad (4 points, a b c d round its edge) with per-vertex normals and
## UVs (0..1 within the atlas region `reg` for the atlas materials). Faces are wound to face the
## way their normals point.
func _emit(key: String, reg: String, ps: Array, ns: Array, uvs: Array, col: Color) -> void:
	var b := _st(key)
	var atlas := key == "vc" or key == "atlas" or key == "gloss" or key == "glow"
	var r := Rect2(0, 0, 1, 1)
	if atlas:
		var rk := reg if reg != "" else "white"
		if not _regions.has(rk):
			_regions[rk] = _region(rk)
		r = _regions[rk]
	var p0: Vector3 = ps[0]
	var p1: Vector3 = ps[1]
	var p2: Vector3 = ps[2]
	var gn := (p1 - p0).cross(p2 - p0)
	var nsum: Vector3 = ns[0] + ns[1] + ns[2]
	var np := ps.size()
	if np == 4:
		var p3: Vector3 = ps[3]
		gn += (p2 - p0).cross(p3 - p0)
		nsum += ns[3]
	var shade := key != "glow" and _ao_mode >= 0
	var base := b.v.size()
	for i in np:
		var p: Vector3 = ps[i]
		var k := _occ(p) if shade else 1.0
		b.v.append(p)
		b.n.append(ns[i])
		b.c.append(Color(col.r * k, col.g * k, col.b * k, col.a))
		b.t.append(r.position + (uvs[i] as Vector2) * r.size if atlas else uvs[i])
	# (Godot's front faces wind clockwise.)
	if gn.dot(nsum) > 0.0:
		b.i.append(base)
		b.i.append(base + 2)
		b.i.append(base + 1)
		if np == 4:
			b.i.append(base)
			b.i.append(base + 3)
			b.i.append(base + 2)
	else:
		b.i.append(base)
		b.i.append(base + 1)
		b.i.append(base + 2)
		if np == 4:
			b.i.append(base)
			b.i.append(base + 2)
			b.i.append(base + 3)


## A flat quad a-b-c-d, facing the side it is counter-clockwise from.
func _quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, uv: Array = UV4, reg := "") -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		n = (c - a).cross(d - a)
	n = n.normalized()
	_emit(key, reg, [a, b, c, d], [n, n, n, n], uv, col)


## A flat print (poster, paper, label) of size (w, h) in its local XY plane, facing local +z.
## `sub` picks part of the atlas region.
func _print(reg: String, xf: Transform3D, size: Vector2, col := Color.WHITE, key := "atlas", sub := Rect2(0, 0, 1, 1)) -> void:
	var h := size * 0.5
	var uv := [sub.position + Vector2(0, sub.size.y), sub.position + sub.size, sub.position + Vector2(sub.size.x, 0), sub.position]
	_quad(key, xf * Vector3(-h.x, -h.y, 0), xf * Vector3(h.x, -h.y, 0), xf * Vector3(h.x, h.y, 0), xf * Vector3(-h.x, h.y, 0), col, uv, reg)


## A box of `size` whose transform is `xf` (centred), each face UV-mapped 0..1 (or by `tile`
## world units when tile > 0). Sharp edges: for small things.
func box(key: String, size: Vector3, xf: Transform3D, col: Color, tile := 0.0, reg := "") -> void:
	var tg := _target(key, reg)
	var b: Buf = tg[0]
	var atlas: bool = tg[1]
	var r: Rect2 = tg[2]
	var shade: bool = tg[3]
	var h := size * 0.5
	var bas := xf.basis
	var c := [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
			Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	for f in BOX_FACES:
		var fs: Vector2 = Vector2(size.x, size.y) if f[5] == 0 else (Vector2(size.z, size.y) if f[5] == 1 else Vector2(size.x, size.z))
		var s := fs / tile if tile > 0.0 else Vector2.ONE
		var uvs := [Vector2(0, s.y), Vector2(s.x, s.y), Vector2(s.x, 0), Vector2(0, 0)]
		var nw := (bas * (f[4] as Vector3)).normalized()
		var base := b.v.size()
		for q in 4:
			_put(b, xf * (c[f[q]] as Vector3), nw, col, uvs[q], atlas, r, shade)
		# (Each face's corners run counter-clockwise seen from outside: Godot's front is clockwise.)
		b.i.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))


func bx(key: String, size: Vector3, pos: Vector3, col: Color, rot := Vector3.ZERO) -> void:
	box(key, size, Transform3D(Basis.from_euler(rot), pos), col)


func _rb_pt(h: Vector3, hi: Vector3, i: int, s: float, sg: Vector3) -> Vector3:
	var p := Vector3(sg.x * hi.x, sg.y * hi.y, sg.z * hi.z)
	p[i] = s * h[i]
	return p


func _rb_uv(p: Vector3, i: int, size: Vector3, tile: float) -> Vector2:
	var a := 2 if i == 0 else 0
	var b := 2 if i == 1 else 1
	if tile > 0.0:
		return Vector2(p[a] / tile, (p[b] if i == 1 else -p[b]) / tile)
	var u: float = p[a] / size[a] + 0.5
	var v: float = (p[b] / size[b] + 0.5) if i == 1 else (0.5 - p[b] / size[b])
	return Vector2(u, v)


## Appends one vertex to buffer `b` (occlusion, atlas region `r` when `atlas`); returns its index.
func _put(b: Buf, p: Vector3, n: Vector3, col: Color, uv: Vector2, atlas: bool, r: Rect2, shade: bool) -> int:
	var k := _occ(p) if shade else 1.0
	b.v.append(p)
	b.n.append(n)
	b.c.append(Color(col.r * k, col.g * k, col.b * k, col.a))
	b.t.append(r.position + uv * r.size if atlas else uv)
	return b.v.size() - 1


## A triangle of existing vertices, wound to face the way their normals point.
func _tri(b: Buf, i0: int, i1: int, i2: int) -> void:
	var p0 := b.v[i0]
	if (b.v[i1] - p0).cross(b.v[i2] - p0).dot(b.n[i0] + b.n[i1] + b.n[i2]) > 0.0:
		b.i.append(i0)
		b.i.append(i2)
		b.i.append(i1)
	else:
		b.i.append(i0)
		b.i.append(i1)
		b.i.append(i2)


## The buffer, atlas flag, atlas region and shading flag for material `key` and region `reg`.
func _target(key: String, reg: String) -> Array:
	var atlas := key == "vc" or key == "atlas" or key == "gloss" or key == "glow"
	var r := Rect2(0, 0, 1, 1)
	if atlas:
		var rk := reg if reg != "" else "white"
		if not _regions.has(rk):
			_regions[rk] = _region(rk)
		r = _regions[rk]
	return [_st(key), atlas, r, key != "glow" and _ao_mode >= 0]


## A bevelled box: flat faces joined by chamfers whose normals blend between the faces, so its
## edges catch the light like a rounded edge. `bev` is the chamfer width. (Every vertex is a corner
## of one of the six inset faces, with that face's normal: 24 vertices, 44 triangles.)
func rbox(key: String, size: Vector3, xf: Transform3D, col: Color, bev := 8.0, tile := 0.0, reg := "") -> void:
	var h := size * 0.5
	var bv := minf(bev, minf(h.x, minf(h.y, h.z)) * 0.8)
	# (Small bevels on small things are not worth their vertices.)
	if bv < 2.5 or (bv < 5.0 and maxf(size.x, maxf(size.y, size.z)) < 160.0):
		box(key, size, xf, col, tile, reg)
		return
	var tg := _target(key, reg)
	var b: Buf = tg[0]
	var atlas: bool = tg[1]
	var r: Rect2 = tg[2]
	var shade: bool = tg[3]
	var hi := h - Vector3(bv, bv, bv)
	var bas := xf.basis
	# idx[i][s][corner code] = vertex index; corner code = the signs of x, y, z as bits.
	var idx := {}
	for i in 3:
		var j := (i + 1) % 3
		var k := (i + 2) % 3
		for si in 2:
			var s := -1.0 if si == 0 else 1.0
			var nl := Vector3.ZERO
			nl[i] = s
			var nw := (bas * nl).normalized()
			var ring := []
			for sg2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var sg := Vector3.ZERO
				sg[j] = sg2.x
				sg[k] = sg2.y
				sg[i] = s
				var p := _rb_pt(h, hi, i, s, sg)
				var vi := _put(b, xf * p, nw, col, _rb_uv(p, i, size, tile), atlas, r, shade)
				idx[i * 100 + int(sg.x > 0) * 4 + int(sg.y > 0) * 2 + int(sg.z > 0)] = vi
				ring.append(vi)
			_tri(b, ring[0], ring[1], ring[2])
			_tri(b, ring[0], ring[2], ring[3])
	# Edge chamfers: between faces i and j along axis k.
	for i in 3:
		for j in range(i + 1, 3):
			var k := 3 - i - j
			for si in 2:
				for sj in 2:
					var c0 := Vector3.ZERO
					c0[i] = si
					c0[j] = sj
					var c1 := c0
					c1[k] = 1
					var code0 := int(c0.x) * 4 + int(c0.y) * 2 + int(c0.z)
					var code1 := int(c1.x) * 4 + int(c1.y) * 2 + int(c1.z)
					var a0: int = idx[i * 100 + code0]
					var b0: int = idx[j * 100 + code0]
					var b1: int = idx[j * 100 + code1]
					var a1: int = idx[i * 100 + code1]
					_tri(b, a0, b0, b1)
					_tri(b, a0, b1, a1)
	# Corners.
	for code in 8:
		_tri(b, idx[code], idx[100 + code], idx[200 + code])


## A cylinder (axis local Y) of radius r0 at the bottom and r1 at the top, smooth-shaded sides.
func cyl(key: String, r0: float, r1: float, height: float, xf: Transform3D, col: Color, segs := 12, caps := true, reg := "") -> void:
	var tg := _target(key, reg)
	var b: Buf = tg[0]
	var atlas: bool = tg[1]
	var r: Rect2 = tg[2]
	var shade: bool = tg[3]
	var bas := xf.basis
	var slope := (r0 - r1) / maxf(height, 0.001)
	var hh := height * 0.5
	var nu := (bas * Vector3.UP).normalized()
	var bot := []
	var top := []
	for i in segs + 1:
		var a := TAU * i / segs
		var c := cos(a)
		var sn := sin(a)
		var nw := (bas * Vector3(c, slope, sn)).normalized()
		var u := float(i) / segs
		bot.append(_put(b, xf * Vector3(c * r0, -hh, sn * r0), nw, col, Vector2(u, 1), atlas, r, shade))
		top.append(_put(b, xf * Vector3(c * r1, hh, sn * r1), nw, col, Vector2(u, 0), atlas, r, shade))
	for i in segs:
		_tri(b, bot[i + 1], bot[i], top[i])
		_tri(b, bot[i + 1], top[i], top[i + 1])
	if not caps:
		return
	for end in 2:
		var rr := r1 if end == 1 else r0
		if rr <= 0.01:
			continue
		var y := hh if end == 1 else -hh
		var nn := nu if end == 1 else -nu
		var ctr := _put(b, xf * Vector3(0, y, 0), nn, col, Vector2(0.5, 0.5), atlas, r, shade)
		var ring := []
		for i in segs + 1:
			var a := TAU * i / segs
			ring.append(_put(b, xf * Vector3(cos(a) * rr, y, sin(a) * rr), nn, col, Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5), atlas, r, shade))
		for i in segs:
			_tri(b, ctr, ring[i], ring[i + 1])


## A cylinder from a to b.
func _tube(a: Vector3, b: Vector3, r: float, col: Color, key := "gloss", segs := 6, caps := false) -> void:
	var d := b - a
	if d.length() < 0.01:
		return
	var up := d.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up)
	cyl(key, r, r, d.length(), Transform3D(Basis(side, up, fwd), (a + b) * 0.5), col, segs, caps)


## A cable or cord through `pts`, smoothed (Catmull-Rom).
func cable(pts: Array, r: float, col: Color, key := "gloss", sub := 3) -> void:
	var sm := []
	for i in pts.size() - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, pts.size() - 1)]
		for s in sub:
			var t := float(s) / sub
			var t2 := t * t
			var t3 := t2 * t
			sm.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	sm.append(pts[pts.size() - 1])
	for i in sm.size() - 1:
		var a: Vector3 = sm[i]
		var b: Vector3 = sm[i + 1]
		var d := (b - a).normalized() * r * 0.4
		_tube(a - d, b + d, r, col, key, 5 if r < 10.0 else 7)


## The inside of an open cone (a lamp shade's lining): normals facing the axis.
func _lining(r0: float, r1: float, height: float, xf: Transform3D, col: Color, segs := 16) -> void:
	var rows := []
	var uvs := []
	for j in 3:
		var v := j / 2.0
		var r := lerpf(r0, r1, v)
		var row := []
		var urow := []
		for i in segs + 1:
			var a := TAU * i / segs
			row.append(Vector3(cos(a) * r, (v - 0.5) * height, sin(a) * r))
			urow.append(Vector2(float(i) / segs, v))
		rows.append(row)
		uvs.append(urow)
	_surf("glow", "", rows, uvs, xf, col, Vector3(0, -height * 4.0, 0), true, 0.0, [], true)


func _spow(t: float, e: float) -> float:
	return signf(t) * pow(absf(t), e)


## An ellipsoid (e1 = e2 = 1) or a rounded superellipsoid (smaller exponents are boxier): pillows,
## cushions, plush toys, a ball.
func blob(key: String, radii: Vector3, xf: Transform3D, col: Color, segs := 12, rings := 8, e1 := 1.0, e2 := 1.0, reg := "") -> void:
	var rmax := maxf(radii.x, maxf(radii.y, radii.z))
	if rmax < 20.0:
		segs = mini(segs, 6)
		rings = mini(rings, 4)
	elif rmax < 60.0:
		segs = mini(segs, 10)
		rings = mini(rings, 6)
	var rows := []
	var uvr := []
	for j in rings + 1:
		var ph := -PI * 0.5 + PI * j / rings
		var row := []
		var urow := []
		for i in segs + 1:
			var th := TAU * i / segs
			var cp := _spow(cos(ph), e1)
			row.append(Vector3(radii.x * cp * _spow(cos(th), e2), radii.y * _spow(sin(ph), e1), radii.z * cp * _spow(sin(th), e2)))
			urow.append(Vector2(float(i) / segs, 1.0 - float(j) / rings))
		rows.append(row)
		uvr.append(urow)
	_surf(key, reg, rows, uvr, xf, col, Vector3.ZERO, true)


## A grid surface (rows of local points) with smooth normals from central differences, facing away
## from the local point `ref`. `thick` > 0 closes its open edges with a strip that thick (fabric
## with body). `mask` (one bool per cell) leaves cells out.
func _surf(key: String, reg: String, rows: Array, uvs: Array, xf: Transform3D, col: Color, ref: Vector3, wrap_u := false, thick := 0.0, mask: Array = [], invert := false, drape_ref := false) -> void:
	var nr := rows.size()
	var nc := (rows[0] as Array).size()
	var bas := xf.basis
	var P := PackedVector3Array()
	P.resize(nr * nc)
	for j in nr:
		var row: Array = rows[j]
		for i in nc:
			P[j * nc + i] = row[i]
	var W := []
	var N := []
	for j in nr:
		var wrow := []
		var nrow := []
		var jd := maxi(j - 1, 0) * nc
		var ju := mini(j + 1, nr - 1) * nc
		for i in nc:
			var p := P[j * nc + i]
			var il := i - 1
			var ir := i + 1
			if wrap_u:
				if il < 0:
					il = nc - 2
				if ir > nc - 1:
					ir = 1
			else:
				il = maxi(il, 0)
				ir = mini(ir, nc - 1)
			var n := (P[j * nc + ir] - P[j * nc + il]).cross(P[ju + i] - P[jd + i])
			var out := p - ref
			if drape_ref:
				# (Away from the fold's ridge line, along local x: sideways where it hangs.)
				out = Vector3(0, maxf(out.y, 0.0), out.z)
			if n.length_squared() < 1e-6:
				n = out
			if (n.dot(out) < 0.0) != invert:
				n = -n
			wrow.append(xf * p)
			nrow.append((bas * n).normalized())
		W.append(wrow)
		N.append(nrow)
	var cells := nc - 1
	# The grid's vertices once, its cells as indexed quads wound to face their normals.
	var b := _st(key)
	var atlas := key == "vc" or key == "atlas" or key == "gloss" or key == "glow"
	var r := Rect2(0, 0, 1, 1)
	if atlas:
		r = _region(reg if reg != "" else "white")
	var shade := key != "glow" and _ao_mode >= 0
	var base := b.v.size()
	for j in nr:
		for i in nc:
			var p: Vector3 = W[j][i]
			var k := _occ(p) if shade else 1.0
			b.v.append(p)
			b.n.append(N[j][i])
			b.c.append(Color(col.r * k, col.g * k, col.b * k, col.a))
			b.t.append(r.position + (uvs[j][i] as Vector2) * r.size if atlas else uvs[j][i])
	for j in nr - 1:
		for i in cells:
			if not mask.is_empty() and not mask[j * cells + i]:
				continue
			var a0 := base + j * nc + i
			var a1 := a0 + 1
			var a2 := a0 + nc + 1
			var a3 := a0 + nc
			var q0: Vector3 = b.v[a0]
			var gn := (b.v[a1] - q0).cross(b.v[a2] - q0) + (b.v[a2] - q0).cross(b.v[a3] - q0)
			if gn.dot(b.n[a0] + b.n[a1] + b.n[a2] + b.n[a3]) > 0.0:
				b.i.append_array(PackedInt32Array([a0, a2, a1, a0, a3, a2]))
			else:
				b.i.append_array(PackedInt32Array([a0, a1, a2, a0, a2, a3]))
	if thick <= 0.0:
		return
	for j in nr - 1:
		for i in cells:
			if not mask.is_empty() and not mask[j * cells + i]:
				continue
			var cc: Vector3 = ((W[j][i] as Vector3) + (W[j + 1][i + 1] as Vector3)) * 0.5
			# [edge a, edge b, neighbour j, neighbour i]
			for e in [[Vector2i(i, j), Vector2i(i + 1, j), j - 1, i], [Vector2i(i, j + 1), Vector2i(i + 1, j + 1), j + 1, i],
					[Vector2i(i, j), Vector2i(i, j + 1), j, i - 1], [Vector2i(i + 1, j), Vector2i(i + 1, j + 1), j, i + 1]]:
				var nj: int = e[2]
				var ni: int = e[3]
				var open := nj < 0 or nj >= nr - 1 or ni < 0 or ni >= cells
				if wrap_u and (ni < 0 or ni >= cells):
					open = false
				if not open and not mask.is_empty():
					open = not mask[nj * cells + ni]
				if not open:
					continue
				var ea: Vector2i = e[0]
				var eb: Vector2i = e[1]
				var a: Vector3 = W[ea.y][ea.x]
				var bb: Vector3 = W[eb.y][eb.x]
				var a2: Vector3 = a - (N[ea.y][ea.x] as Vector3) * thick
				var b2: Vector3 = bb - (N[eb.y][eb.x] as Vector3) * thick
				var sn := (bb - a).cross(a2 - a).normalized()
				if sn.dot(a - cc) < 0.0:
					sn = -sn
				_emit(key, reg, [a, bb, b2, a2], [sn, sn, sn, sn], [Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.05), Vector2(0, 0.05)], col)


## Cloth hung over an edge (a chair back, a hook, a drawer's front, the bed's side): the edge runs
## along local x at the origin; `back` hangs down on the local -z side, `front` on the +z side, over
## a rounded fold of radius r; it flares and wrinkles as it hangs.
func drape(xf: Transform3D, width: float, back: float, front: float, col: Color, r := 20.0, flare := 0.25, key := "fabric", n := 10, thick := 8.0) -> void:
	var L := back + PI * r + front
	var nv := n * 2
	var ph := _r.randf() * 10.0
	var rows := []
	var uvs := []
	for j in nv + 1:
		var sv := float(j) / nv * L
		var d := 0.0
		var z0 := 0.0
		var y0 := 0.0
		var sgn := 0.0
		if sv < back:
			d = back - sv
			z0 = -r
			y0 = -d
			sgn = -1.0
		elif sv < back + PI * r:
			var th := (sv - back) / r
			z0 = -r * cos(th)
			y0 = r * sin(th)
		else:
			d = sv - back - PI * r
			z0 = r
			y0 = -d
			sgn = 1.0
		var row := []
		var urow := []
		for i in n + 1:
			var u := float(i) / n
			var k := d / maxf(maxf(front, back), 1.0)
			var x := (u - 0.5) * width * (1.0 + flare * k)
			var wr := (16.0 * sin(u * 9.0 + d * 0.012 + ph) + 8.0 * sin(u * 23.0 - d * 0.03)) * smoothstep(0.0, 120.0, d)
			row.append(Vector3(x, y0 + 10.0 * sin(u * 7.0 + ph) * smoothstep(0.0, 60.0, d), z0 + sgn * (wr + d * flare * 0.12)))
			urow.append(Vector2(u * width / 300.0, sv / 300.0))
		rows.append(row)
		uvs.append(urow)
	_surf(key, "", rows, uvs, xf, col, Vector3(0, -r, 0), false, thick, [], false, true)


## Where garment shapes cover a cloth (u, v in 0..1).
func _garment(shape: String, u: float, v: float) -> bool:
	match shape:
		"tee":
			var body := absf(u - 0.5) < 0.24 and v > 0.05 and v < 0.95
			var sleeves := v > 0.62 and v < 0.95 and absf(u - 0.5) < 0.24 + (v - 0.62) * 0.9 + 0.02
			var neck := v > 0.88 and absf(u - 0.5) < 0.08
			return (body or sleeves) and not neck
		"jeans":
			if v > 0.72:
				return absf(u - 0.5) < 0.3
			var l := 0.5 - 0.15 - (0.72 - v) * 0.2
			var r := 0.5 + 0.15 + (0.72 - v) * 0.2
			return absf(u - l) < 0.13 or absf(u - r) < 0.13
		"sock":
			return (v > 0.35 and absf(u - 0.35) < 0.18) or (v <= 0.4 and absf(u - 0.5 - (0.4 - v) * 0.6) < 0.2 and v > 0.02)
	return true


## A cloth: a grid over `size` (x by z) at transform xf, heights from a crumple function, hanging
## down at its sides by `drape_edges`, `thick` thick, in a garment shape (see _garment).
func cloth(key: String, size: Vector2, xf: Transform3D, col: Color, lumps: float, drape_edges := 0.0, n := 14, uv_scale := 1.0, thick := 8.0, shape := "", reg := "") -> void:
	var rows := []
	var uvs := []
	var ph := _r.randf() * 10.0
	for j in n + 1:
		var row := []
		var urow := []
		for i in n + 1:
			var u := float(i) / n
			var v := float(j) / n
			var x := (u - 0.5) * size.x
			var z := (v - 0.5) * size.y
			var w := sin(u * 7.3 + v * 2.1 + ph) * 0.5 + sin(u * 3.1 - v * 6.7 + ph * 2.0) * 0.35 + sin(u * 13.0 + v * 11.0) * 0.12
			var y := lumps * w
			if drape_edges > 0.0:
				var edge := maxf(absf(u - 0.5), absf(v - 0.5)) * 2.0
				y -= smoothstep(0.8, 1.0, edge) * drape_edges
			else:
				y = lumps * (0.55 + 0.45 * w)
			row.append(Vector3(x, maxf(y, 0.0) if drape_edges <= 0.0 else y, z))
			urow.append(Vector2(u * uv_scale, v * uv_scale))
		rows.append(row)
		uvs.append(urow)
	var mask := []
	if shape != "":
		for j in n:
			for i in n:
				mask.append(_garment(shape, (i + 0.5) / n, (j + 0.5) / n))
	_surf(key, reg, rows, uvs, xf, col, Vector3(0, -100000, 0), false, thick, mask)


## A flat disc (sticker, rug, lid print) in local XY facing +z, radii (rx, ry), UVs over the atlas
## sub-rect `sub` of `reg`.
func _disc(key: String, reg: String, xf: Transform3D, rx: float, ry: float, col: Color, segs := 16, sub := Rect2(0, 0, 1, 1)) -> void:
	var n := (xf.basis * Vector3.BACK).normalized()
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var uv := [sub.position + sub.size * 0.5,
				sub.position + sub.size * Vector2(0.5 + cos(a0) * 0.5, 0.5 - sin(a0) * 0.5),
				sub.position + sub.size * Vector2(0.5 + cos(a1) * 0.5, 0.5 - sin(a1) * 0.5)]
		_emit(key, reg, [xf.origin, xf * Vector3(cos(a0) * rx, sin(a0) * ry, 0), xf * Vector3(cos(a1) * rx, sin(a1) * ry, 0)], [n, n, n], uv, col)


## A round sticker (0..7: star, heart, rainbow, bolt, smile, planet, A+, dino) at xf, facing +z.
func sticker(i: int, xf: Transform3D, r := 32.0) -> void:
	_disc("atlas", "stickers", xf, r, r, Color.WHITE, 14, Rect2((i % 4) * 0.25, (i / 4) * 0.5, 0.25, 0.5))


func _jit(c: Color, k := 0.06) -> Color:
	return Color(clampf(c.r * _r.randf_range(1.0 - k, 1.0 + k), 0, 1), clampf(c.g * _r.randf_range(1.0 - k, 1.0 + k), 0, 1), clampf(c.b * _r.randf_range(1.0 - k, 1.0 + k), 0, 1))


func _at(pos: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), pos)


func _foot(x0: float, z0: float, x1: float, z1: float) -> void:
	_feet.append(Rect2(x0, z0, x1 - x0, z1 - z0))


# --- Small things -----------------------------------------------------------------------------

## A book: `size` = (thickness, height, depth) standing on its bottom at xf.origin, spine toward
## local +z; cover colour `col`, spine art column `spine` (0..19) of the atlas, pages showing
## cream at the top and the fore-edge.
func book(size: Vector3, xf: Transform3D, col: Color, spine := -1) -> void:
	var h := size * 0.5
	var c := Transform3D(xf.basis, xf * Vector3(0, h.y, 0))
	box("vc", size, c, col)
	var pc := Color(0.92, 0.89, 0.8)
	var ins := minf(3.0, h.x * 0.3)
	_quad("vc", c * Vector3(-h.x + ins, h.y + 0.6, -h.z + 1), c * Vector3(-h.x + ins, h.y + 0.6, h.z - 7), c * Vector3(h.x - ins, h.y + 0.6, h.z - 7), c * Vector3(h.x - ins, h.y + 0.6, -h.z + 1), pc)
	_quad("vc", c * Vector3(-h.x + ins, -h.y + 3, -h.z - 0.6), c * Vector3(-h.x + ins, h.y - 3, -h.z - 0.6), c * Vector3(h.x - ins, h.y - 3, -h.z - 0.6), c * Vector3(h.x - ins, -h.y + 3, -h.z - 0.6), pc)
	if spine >= 0:
		var u0 := (spine % 20) / 20.0
		var u1 := u0 + 1.0 / 20.0 - 0.004
		var sp := Transform3D(c.basis, c * Vector3(0, 0, h.z + 0.6))
		_print("spines", sp, Vector2(size.x - 1.0, size.y - 2.0), col, "atlas", Rect2(u0 + 0.002, 0, u1 - u0, 1))


## A lying-flat stack of books or magazines: bottom at pos.
func book_stack(pos: Vector3, count: int, yaw: float, cols: Array, w := 180.0, d := 250.0, t := 30.0) -> float:
	var y := 0.0
	for k in count:
		var th := t * _r.randf_range(0.7, 1.3)
		var ww := w * _r.randf_range(0.85, 1.1)
		var dd := d * _r.randf_range(0.85, 1.1)
		# (A book lying flat: its local y is the world's thickness.)
		var bas := Basis(Vector3.UP, yaw + _r.randf_range(-0.2, 0.2)) * Basis(Vector3.FORWARD, PI * 0.5)
		book(Vector3(th, ww, dd), Transform3D(bas, pos + Vector3(0, y + th * 0.5, 0) + bas * Vector3(0, -ww * 0.5, 0)), _jit(cols[k % cols.size()], 0.1), _r.randi() % 20)
		y += th
	return y


## A comic or magazine lying flat (cover `idx` of `reg`: 6 comics or 4 magazines), bottom at pos.
func comic(pos: Vector3, yaw: float, idx: int, reg := "comics", open := false) -> void:
	var n := 6 if reg == "comics" else 4
	var size := Vector2(170, 255) if reg == "comics" else Vector2(210, 280)
	var bas := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5)
	box("vc", Vector3(size.x, size.y, 3), Transform3D(bas, pos + Vector3(0, 1.5, 0)), Color(0.93, 0.92, 0.88))
	var sub := Rect2(float(idx % n) / n + 0.003, 0, 1.0 / n - 0.006, 1)
	_print(reg, Transform3D(bas, pos + Vector3(0, 3.3, 0)), size, Color.WHITE, "atlas", sub)
	if open:
		# The first pages flipped over beside it.
		var b2 := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, 0.18) * Basis(Vector3.RIGHT, -PI * 0.5)
		_print("white", Transform3D(b2, pos + Basis(Vector3.UP, yaw) * Vector3(-size.x, 18, 0)), size, Color(0.9, 0.88, 0.8))


## A cassette tape (in its clear case when `cased`), lying flat, bottom at pos.
func cassette(pos: Vector3, yaw: float, label: int, cased := true, tilt := 0.0) -> void:
	var bas := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
	var sub := Rect2(label * 0.25 + 0.004, 0, 0.242, 1)
	if cased:
		rbox("gloss", Vector3(110, 17, 70), Transform3D(bas, pos + bas * Vector3(0, 8.5, 0)), Color(0.55, 0.58, 0.6), 2.0)
		_print("cassette", Transform3D(bas * Basis(Vector3.RIGHT, -PI * 0.5), pos + bas * Vector3(0, 17.4, 0)), Vector2(100, 62), Color.WHITE, "atlas", sub)
		# The j-card's spine along the case's edge.
		box("vc", Vector3(104, 13, 1), Transform3D(bas, pos + bas * Vector3(0, 8.5, 35.4)), [Color(0.9, 0.3, 0.25), Color(0.95, 0.65, 0.2), Color(0.3, 0.55, 0.8), Color(0.35, 0.7, 0.4)][label % 4])
	else:
		rbox("gloss", Vector3(100, 12, 63), Transform3D(bas, pos + bas * Vector3(0, 6, 0)), Color(0.1, 0.1, 0.11), 2.0)
		_print("cassette", Transform3D(bas * Basis(Vector3.RIGHT, -PI * 0.5), pos + bas * Vector3(0, 12.4, 0)), Vector2(86, 46), Color.WHITE, "atlas", sub)


## A game cartridge (generic: a grey slab with ridges and a picture label) centred at pos.
func cartridge(xf: Transform3D, label: int) -> void:
	rbox("gloss", Vector3(118, 96, 20), xf, Color(0.42, 0.42, 0.45), 3.0)
	for k in 3:
		box("vc", Vector3(100, 4, 22), Transform3D(xf.basis, xf * Vector3(0, -30 - k * 9, 0)), Color(0.34, 0.34, 0.36))
	var sub := Rect2((label % 2) * 0.5 + 0.01, (label / 2 % 2) * 0.5 + 0.01, 0.48, 0.48)
	_print("carts", Transform3D(xf.basis, xf * Vector3(0, 12, 10.6)), Vector2(96, 64), Color.WHITE, "atlas", sub)


## A pencil (or pen) from a to b.
func pencil(a: Vector3, b: Vector3, col: Color, pen := false) -> void:
	var d := (b - a)
	var tip := a + d * 0.9
	_tube(a, tip, 4.0, col, "gloss", 6, true)
	if pen:
		_tube(tip, b, 3.0, Color(0.1, 0.1, 0.1), "gloss", 6, true)
	else:
		_tube(tip, b, 2.2, Color(0.9, 0.78, 0.55), "vc", 6, true)
		_tube(a - d.normalized() * 10.0, a, 4.2, Color(0.95, 0.6, 0.65), "vc", 6, true)


# --- The tank corner -------------------------------------------------------------------------

## The aquarium's dresser and hardware: the hood with its light strip, a hang-on filter, the air pump
## and its tubing, cords to a power strip.
func _tank_corner(tmin: Vector3, tmax: Vector3) -> void:
	var fy := floor_y
	var sw := tmax.x - tmin.x + 360.0
	var sd := tmax.z - tmin.z + 60.0
	var sz := (tmin.z + tmax.z) * 0.5
	var top := tmin.y - 25.0
	var front := sz + sd * 0.5
	var wood := Color(0.62, 0.42, 0.27)
	_foot(-sw * 0.5, sz - sd * 0.5, sw * 0.5, front)
	# A dresser as the stand: a plinth, a carcass, a thick top with a lip, three drawers (the top one
	# open, a sleeve and a sock hanging out), brass bail pulls, stickers.
	rbox("wood", Vector3(sw + 26, 28, sd + 24), _at(Vector3(0, top - 14, sz)), wood.lightened(0.05), 8.0, 700.0)
	rbox("wood", Vector3(sw, top - 28 - fy - 50, sd), _at(Vector3(0, (fy + 50 + top - 28) * 0.5, sz)), wood.darkened(0.05), 6.0, 700.0)
	rbox("wood", Vector3(sw - 30, 56, sd - 30), _at(Vector3(0, fy + 28, sz - 10)), wood.darkened(0.35), 4.0, 700.0)
	var dh := (top - 28 - fy - 50 - 4 * 14) / 3.0
	for i in 3:
		var dy := fy + 50 + 14 + dh * 0.5 + i * (dh + 14)
		var out := 90.0 if i == 2 else (18.0 if i == 0 else 0.0)
		var fz := front + 11 + out
		rbox("wood", Vector3(sw - 44, dh, 22), _at(Vector3(0, dy, fz)), _jit(wood.lightened(0.1), 0.03), 7.0, 700.0)
		# (A shallow routed line round the front.)
		for yy in [-dh * 0.5 + 16, dh * 0.5 - 16]:
			box("vc", Vector3(sw - 90, 3, 1), _at(Vector3(0, dy + yy, fz + 11.3)), wood.darkened(0.3))
		if out > 0.0:
			# The drawer's sides, and what is inside.
			for sx in [-1.0, 1.0]:
				box("wood", Vector3(14, dh - 30, out + 20), _at(Vector3(sx * (sw * 0.5 - 40), dy - 8, front + out * 0.5 - 4)), wood.lightened(0.15), 300.0)
			box("vc", Vector3(sw - 100, 4, out), _at(Vector3(0, dy + dh * 0.5 - 40, front + out * 0.5 - 8)), Color(0.12, 0.09, 0.07))
		for kx in [-sw * 0.27, sw * 0.27]:
			var pp := Vector3(kx, dy + 6, fz + 12)
			rbox("gloss", Vector3(70, 26, 5), _at(pp), Color(0.78, 0.62, 0.3), 2.0)
			for s in [-1.0, 1.0]:
				_tube(pp + Vector3(s * 28, 4, 2), pp + Vector3(s * 26, -18, 14), 3.5, Color(0.82, 0.68, 0.35), "gloss", 6)
			_tube(pp + Vector3(-26, -18, 14), pp + Vector3(26, -18, 14), 3.5, Color(0.82, 0.68, 0.35), "gloss", 6)
		if i == 2:
			# Clothes stuffed in the open top drawer: a lump of t-shirts, a flannel sleeve and a sock out.
			cloth("fabric", Vector2(sw - 140, out + 60), _at(Vector3(0, dy + dh * 0.5 - 42, front + out * 0.5 - 20)), Color(0.35, 0.45, 0.62), 28.0, 0.0, 8, 2.0, 6.0)
			# (The drawer front's top edge, the fold's ridge along x.)
			var edge := Vector3(0, dy + dh * 0.5 + 4, fz)
			drape(Transform3D(Basis(Vector3.BACK, 0.12), edge + Vector3(-170, 0, 0)), 95.0, 60.0, 290.0, Color(0.72, 0.2, 0.18), 12.0, 0.35, "fabric", 5)
			drape(Transform3D(Basis(Vector3.BACK, -0.08), edge + Vector3(210, 0, 0)), 72.0, 50.0, 190.0, Color(0.95, 0.95, 0.92), 11.0, 0.15, "fabric", 4)
	# Stickers stuck on the drawer fronts and the side.
	var dy0 := fy + 50 + 14 + dh * 0.5
	sticker(0, _at(Vector3(-sw * 0.36, dy0 + (dh + 14) * 2 + 40, front + 22 + 90 + 0.6)), 34.0)
	sticker(2, _at(Vector3(sw * 0.12, dy0 + (dh + 14) + 30, front + 22.6)), 38.0)
	sticker(3, Transform3D(Basis(Vector3.BACK, 0.3), Vector3(sw * 0.38, dy0 + (dh + 14) - 40, front + 22.6)), 30.0)
	sticker(7, _at(Vector3(-sw * 0.1, dy0 - 20, front + 40.6)), 30.0)
	sticker(4, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-sw * 0.5 - 0.8, dy0 + (dh + 14) * 1.5, sz + 80)), 36.0)
	sticker(1, Transform3D(Basis(Vector3.UP, -PI * 0.5) * Basis(Vector3.BACK, -0.2), Vector3(-sw * 0.5 - 0.8, dy0 + (dh + 14) * 2.2, sz - 60)), 28.0)
	# The glass's black plastic rims and the hood (a lid with a light strip under a raised hump).
	var gw := tmax.x - tmin.x
	var gd := tmax.z - tmin.z
	var blk := Color(0.05, 0.05, 0.06)
	rbox("gloss", Vector3(gw + 16, 20, gd + 16), _at(Vector3(0, tmin.y - 10, sz)), blk, 4.0)
	rbox("gloss", Vector3(gw + 16, 18, gd + 16), _at(Vector3(0, tmax.y + 12, sz)), blk, 4.0)
	rbox("gloss", Vector3(gw + 10, 26, gd + 10), _at(Vector3(0, tmax.y + 34, sz)), Color(0.08, 0.08, 0.09), 6.0)
	rbox("gloss", Vector3(gw - 60, 34, gd * 0.5), _at(Vector3(0, tmax.y + 62, sz - gd * 0.1)), Color(0.1, 0.1, 0.11), 10.0)
	box("glow", Vector3(gw - 90, 6, 40), _at(Vector3(0, tmax.y + 20, sz)), Color(0.8, 0.92, 1.0))
	# A feeding hatch (flipped up) on the hood.
	rbox("gloss", Vector3(120, 6, 90), Transform3D(Basis(Vector3.RIGHT, -1.1), Vector3(-150, tmax.y + 80, sz + gd * 0.25)), Color(0.1, 0.1, 0.11), 2.0)
	# Hang-on-back filter at the back right, its intake tube down into the water.
	var fx := tmax.x - 120.0
	rbox("gloss", Vector3(150, 190, 80), _at(Vector3(fx, tmax.y - 20, tmin.z - 45)), Color(0.12, 0.13, 0.14), 10.0)
	rbox("gloss", Vector3(156, 16, 110), _at(Vector3(fx, tmax.y + 82, tmin.z - 35)), Color(0.16, 0.17, 0.18), 5.0)
	cyl("gloss", 9, 9, 210, Transform3D(Basis(), Vector3(fx - 40, tmax.y - 60, tmin.z + 18)), Color(0.12, 0.13, 0.14), 8)
	# Air pump on the dresser, clear tubing up and over the rim, into the tank.
	var pump := Vector3(tmax.x + 110, top + 30, sz - 110)
	blob("gloss", Vector3(70, 32, 48), _at(pump + Vector3(0, 2, 0)), Color(0.26, 0.32, 0.4), 12, 6, 0.6, 0.5)
	box("vc", Vector3(80, 6, 50), _at(pump + Vector3(0, -30, 0)), Color(0.12, 0.12, 0.12))
	cable([pump + Vector3(-50, 10, 0), pump + Vector3(-80, 40, -10), Vector3(tmax.x + 12, tmax.y + 40, tmin.z + 40), Vector3(tmax.x - 20, tmax.y + 20, tmin.z + 40), Vector3(tmax.x - 24, tmax.y - 30, tmin.z + 40)], 4.0, Color(0.75, 0.85, 0.85))
	# Cords down the back to a power strip on the floor.
	var strip := Vector3(tmax.x + 120, fy + 20, tmin.z - 20)
	rbox("gloss", Vector3(320, 40, 70), _at(strip), Color(0.88, 0.86, 0.8), 6.0)
	box("glow", Vector3(24, 10, 18), _at(strip + Vector3(-130, 22, 0)), Color(1.0, 0.3, 0.2))
	for p in [Vector3(fx, tmax.y - 100, tmin.z - 85), pump + Vector3(60, -20, 0), Vector3(0, tmax.y + 40, tmin.z - 30)]:
		var pv: Vector3 = p
		cable([pv, Vector3(pv.x + 20, (pv.y + fy) * 0.5, tmin.z - 55), Vector3(pv.x + 20, fy + 40, tmin.z - 50), strip + Vector3(_r.randf_range(-100, 100), 20, 0)], 5.0, Color(0.08, 0.08, 0.08))


## Beside the tank on the dresser: fish food, a pencil cup, cassettes, a little robot, a water
## conditioner bottle, the net; a kid's drawing of the axolotl taped to the wall.
func _dresser_things(tmin: Vector3, tmax: Vector3) -> void:
	var sz := (tmin.z + tmax.z) * 0.5
	var top := tmin.y - 25.0
	# Left of the tank.
	var ff := Vector3(tmin.x - 95, top, sz + 130)
	cyl("gloss", 34, 34, 95, _at(ff + Vector3(0, 47.5, 0)), Color(0.95, 0.55, 0.12), 16)
	cyl("gloss", 37, 37, 20, _at(ff + Vector3(0, 102, 0)), Color(0.95, 0.88, 0.25), 16)
	_print("carts", Transform3D(Basis(Vector3.UP, 0.4), ff + Vector3(14, 50, 33)), Vector2(40, 46), Color(1.0, 0.9, 0.8), "atlas", Rect2(0.52, 0.02, 0.45, 0.45))
	var pc := Vector3(tmin.x - 110, top, sz - 150)
	cyl("gloss", 36, 32, 105, _at(pc + Vector3(0, 52.5, 0)), Color(0.2, 0.45, 0.8), 14)
	cyl("vc", 30, 30, 2, _at(pc + Vector3(0, 100, 0)), Color(0.05, 0.05, 0.08), 14)
	var pcs := [Color(0.95, 0.8, 0.2), Color(0.9, 0.25, 0.25), Color(0.2, 0.35, 0.8), Color(0.95, 0.8, 0.2), Color(0.1, 0.1, 0.1)]
	for k in 5:
		var a := TAU * k / 5.0
		var base := pc + Vector3(cos(a) * 14, 20, sin(a) * 14)
		pencil(base, base + Vector3(cos(a) * 45 + 10, 175, sin(a) * 40), pcs[k], k == 4)
	# A ruler.
	box("gloss", Vector3(30, 300, 3), Transform3D(Basis(Vector3.FORWARD, 0.25), pc + Vector3(-10, 170, 10)), Color(0.85, 0.9, 0.95))
	# A homework sheet under it all, hanging over the front edge.
	_print("homework", Transform3D(Basis(Vector3.UP, 0.35) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(tmin.x - 115, top + 0.8, sz + 175)), Vector2(170, 220))
	# Cassettes: a little stack at the front and one out of its case.
	for k in 3:
		cassette(Vector3(tmin.x - 100, top + 1.5 + k * 17, sz + 210) + Vector3(_r.randf_range(-6, 6), 0, 0), _r.randf_range(-0.25, 0.25) + PI * 0.5, k)
	cassette(Vector3(tmin.x - 70, top + 51, sz + 195), PI * 0.5 + 0.5, 3, false)
	# Right of the tank: a water conditioner bottle, a little wind-up robot, the net leaning on the glass.
	comic(Vector3(tmax.x + 110, top, sz + 150), 0.35, 4)
	var bt := Vector3(tmax.x + 70, top + 3.5, sz + 170)
	cyl("gloss", 26, 26, 110, _at(bt + Vector3(0, 55, 0)), Color(0.2, 0.6, 0.75), 12)
	cyl("gloss", 12, 16, 30, _at(bt + Vector3(0, 125, 0)), Color(0.95, 0.95, 0.95), 10)
	var rb := Vector3(tmax.x + 150, top + 3.5, sz + 150)
	var ry := Basis(Vector3.UP, -0.6)
	rbox("gloss", Vector3(48, 60, 34), Transform3D(ry, rb + Vector3(0, 46, 0)), Color(0.75, 0.2, 0.2), 5.0)
	rbox("gloss", Vector3(40, 34, 32), Transform3D(ry, rb + Vector3(0, 95, 0)), Color(0.78, 0.78, 0.8), 6.0)
	box("glow", Vector3(28, 7, 2), Transform3D(ry, rb + ry * Vector3(0, 98, 16.5)), Color(1.0, 0.85, 0.2))
	_tube(rb + Vector3(0, 112, 0), rb + Vector3(0, 135, 0), 2.0, Color(0.7, 0.7, 0.72))
	blob("gloss", Vector3(6, 6, 6), _at(rb + Vector3(0, 138, 0)), Color(0.95, 0.3, 0.3), 6, 4)
	for s in [-1.0, 1.0]:
		rbox("gloss", Vector3(12, 40, 14), Transform3D(ry, rb + ry * Vector3(s * 30, 52, 0)), Color(0.78, 0.78, 0.8), 3.0)
		rbox("gloss", Vector3(16, 16, 22), Transform3D(ry, rb + ry * Vector3(s * 12, 8, 0)), Color(0.2, 0.2, 0.22), 3.0)
	# The kid's drawing of the axolotl, taped to the wall above the dresser, and a school photo.
	_print("drawing", Transform3D(Basis(Vector3.BACK, 0.05), Vector3(tmin.x - 110, 150, Z0 + 12)), Vector2(190, 142))
	for c in [Vector3(-90, 66, 0), Vector3(85, 72, 0)]:
		var cv: Vector3 = c
		_print("white", Transform3D(Basis(Vector3.BACK, 0.5 * signf(cv.x)), Vector3(tmin.x - 110, 150, Z0 + 12.6) + cv), Vector2(40, 16), Color(0.95, 0.93, 0.8, 1.0))


## A shelf on brackets above the tank: bookends and a few books, a trophy, a model rocket, a snow
## globe, a toy dinosaur.
func _wall_shelf() -> void:
	var y := 430.0
	var z := Z0 + 100
	var wood := Color(0.6, 0.4, 0.26)
	rbox("wood", Vector3(820, 24, 190), _at(Vector3(-20, y, z)), wood, 5.0, 500.0)
	for sx in [-330.0, 290.0]:
		rbox("gloss", Vector3(18, 120, 14), _at(Vector3(sx, y - 72, Z0 + 12)), Color(0.85, 0.85, 0.82), 3.0)
		_tube(Vector3(sx, y - 128, Z0 + 12), Vector3(sx, y - 12, Z0 + 150), 5.0, Color(0.85, 0.85, 0.82), "gloss", 6)
	var ty := y + 12
	# Books between bookends at the left.
	var bcols := [Color(0.75, 0.2, 0.2), Color(0.2, 0.4, 0.75), Color(0.9, 0.75, 0.25), Color(0.3, 0.6, 0.35), Color(0.55, 0.3, 0.6)]
	var bx0 := -400.0
	rbox("gloss", Vector3(10, 110, 110), _at(Vector3(bx0 - 5, ty + 55, z)), Color(0.2, 0.2, 0.22), 2.0)
	var xx := bx0 + 4.0
	for k in 6:
		var t := _r.randf_range(22, 40)
		var hgt := _r.randf_range(140, 200)
		book(Vector3(t, hgt, _r.randf_range(110, 150)), Transform3D(Basis(), Vector3(xx + t * 0.5, ty, z + 10)), _jit(bcols[k % bcols.size()], 0.12), _r.randi() % 20)
		xx += t + 1.0
	# The last one leaning.
	book(Vector3(30, 180, 130), Transform3D(Basis(Vector3.BACK, -0.35), Vector3(xx + 40, ty, z + 10)), Color(0.85, 0.45, 0.2), 7)
	# A trophy.
	var tr := Vector3(-130, ty, z)
	rbox("wood", Vector3(80, 34, 80), _at(tr + Vector3(0, 17, 0)), Color(0.3, 0.18, 0.12), 4.0, 200.0)
	cyl("gloss", 10, 10, 60, _at(tr + Vector3(0, 64, 0)), Color(0.95, 0.78, 0.3), 8)
	cyl("gloss", 18, 44, 70, _at(tr + Vector3(0, 128, 0)), Color(0.95, 0.78, 0.3), 14)
	for s in [-1.0, 1.0]:
		_tube(tr + Vector3(s * 40, 150, 0), tr + Vector3(s * 58, 120, 0), 5.0, Color(0.95, 0.78, 0.3))
	# A snow globe on a dark base.
	var sg := Vector3(170, ty, z + 10)
	cyl("gloss", 45, 40, 36, _at(sg + Vector3(0, 18, 0)), Color(0.25, 0.15, 0.1), 14)
	blob("gloss", Vector3(44, 44, 44), _at(sg + Vector3(0, 76, 0)), Color(0.75, 0.88, 0.95), 14, 8)
	# A model rocket standing on its fins.
	var rk := Vector3(260, ty, z - 10)
	cyl("gloss", 22, 22, 300, _at(rk + Vector3(0, 170, 0)), Color(0.95, 0.95, 0.92), 12)
	cyl("gloss", 22, 0.5, 70, _at(rk + Vector3(0, 355, 0)), Color(0.9, 0.2, 0.2), 12)
	cyl("gloss", 22.5, 22.5, 26, _at(rk + Vector3(0, 250, 0)), Color(0.2, 0.3, 0.8), 12, false)
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		box("gloss", Vector3(4, 70, 50), Transform3D(Basis(Vector3.UP, -a), rk + Vector3(cos(a) * 40, 50, sin(a) * 40)), Color(0.9, 0.2, 0.2))
	# A toy dinosaur at the right end.
	_dino(Vector3(360, ty, z + 20), -0.5, 0.6, Color(0.35, 0.68, 0.35))


func _dino(p: Vector3, yaw: float, s: float, col: Color) -> void:
	var b := Basis(Vector3.UP, yaw)
	blob("gloss", Vector3(80, 55, 45) * s, Transform3D(b, p + b * Vector3(0, 110, 0) * s), col, 12, 7)
	cable([p + b * Vector3(60, 130, 0) * s, p + b * Vector3(95, 190, 0) * s, p + b * Vector3(110, 230, 0) * s], 20.0 * s, col)
	blob("gloss", Vector3(42, 26, 24) * s, Transform3D(b, p + b * Vector3(130, 238, 0) * s), col, 10, 6)
	cable([p + b * Vector3(-60, 110, 0) * s, p + b * Vector3(-120, 80, 0) * s, p + b * Vector3(-190, 30, 10) * s], 18.0 * s, col)
	for lx in [-35.0, 35.0]:
		for lz in [-28.0, 28.0]:
			cyl("gloss", 14 * s, 14 * s, 90 * s, Transform3D(b, p + b * Vector3(lx, 45, lz) * s), col.darkened(0.1), 8)
	for k in 5:
		box("gloss", Vector3(22, 26, 6) * s, Transform3D(b * Basis(Vector3.BACK, 0.8), p + b * Vector3(-50 + k * 25, 165 - absf(k - 2) * 10, 0) * s), Color(0.9, 0.55, 0.2))


# --- The TV corner ---------------------------------------------------------------------------

## Left of the dresser: a chunky wood-grain CRT on a metal cart, a generic game console with a
## cartridge in it on the lower shelf, controllers trailing their cords across the floor.
func _tv_corner() -> void:
	var fy := floor_y
	var c := Vector3(-880, fy, -70)
	var cb := Basis(Vector3.UP, 0.2)
	var metal := Color(0.2, 0.2, 0.22)
	_foot(-1170, -300, -590, 150)
	for kx in [-270.0, 270.0]:
		for kz in [-190.0, 190.0]:
			rbox("gloss", Vector3(24, 610, 24), Transform3D(cb, c + cb * Vector3(kx, 330, kz)), metal, 4.0)
			blob("gloss", Vector3(22, 20, 22), Transform3D(cb, c + cb * Vector3(kx, 20, kz)), Color(0.08, 0.08, 0.08), 8, 5)
	rbox("wood", Vector3(580, 22, 420), Transform3D(cb, c + cb * Vector3(0, 620, 0)), Color(0.4, 0.28, 0.2), 4.0, 400.0)
	rbox("wood", Vector3(580, 22, 420), Transform3D(cb, c + cb * Vector3(0, 200, 0)), Color(0.4, 0.28, 0.2), 4.0, 400.0)
	sticker(5, Transform3D(cb, c + cb * Vector3(-150, 620, 211)), 26.0)
	sticker(6, Transform3D(cb * Basis(Vector3.BACK, 0.2), c + cb * Vector3(150, 198, 211)), 24.0)
	# The CRT: a wood-grain cabinet, a dark front with the curved screen, knobs and a speaker grille;
	# the tube's tapered back; rabbit ears.
	var tb := Basis(Vector3.UP, 0.42)
	var tv := c + Vector3(-10, 631 + 210, 10)
	rbox("atlas", Vector3(500, 420, 400), Transform3D(tb, tv), Color(0.95, 0.9, 0.85), 16.0, 0.0, "tv_bezel")
	rbox("gloss", Vector3(380, 320, 200), Transform3D(tb, tv + tb * Vector3(0, 10, -260)), Color(0.14, 0.13, 0.13), 30.0)
	rbox("gloss", Vector3(480, 396, 16), Transform3D(tb, tv + tb * Vector3(0, 0, 200)), Color(0.13, 0.13, 0.14), 6.0)
	var sw := 340.0
	var sh := 262.0
	var rows := []
	var uvs := []
	for j in 7:
		var row := []
		var urow := []
		for i in 9:
			var u := i / 8.0
			var v := j / 6.0
			var bulge := 14.0 * (1.0 - pow(2.0 * u - 1.0, 2.0)) * (1.0 - pow(2.0 * v - 1.0, 2.0))
			row.append(Vector3((u - 0.5) * sw, (0.5 - v) * sh, bulge))
			urow.append(Vector2(u, v))
		rows.append(row)
		uvs.append(urow)
	_surf("glow", "crt", rows, uvs, Transform3D(tb, tv + tb * Vector3(-55, 10, 209)), Color(0.9, 0.95, 1.0), Vector3(0, 0, -500))
	# The screen's dark rounded surround.
	rbox("gloss", Vector3(sw + 36, sh + 34, 10), Transform3D(tb, tv + tb * Vector3(-55, 10, 203)), Color(0.05, 0.05, 0.06), 8.0)
	for k in 2:
		cyl("gloss", 17, 15, 22, Transform3D(tb * Basis(Vector3.RIGHT, PI * 0.5), tv + tb * Vector3(175, 110 - k * 70, 214)), Color(0.55, 0.55, 0.58), 10)
	for k in 7:
		box("vc", Vector3(60, 5, 3), Transform3D(tb, tv + tb * Vector3(175, -30 - k * 14, 209)), Color(0.04, 0.04, 0.04))
	box("glow", Vector3(8, 8, 3), Transform3D(tb, tv + tb * Vector3(175, -150, 209)), Color(1.0, 0.25, 0.2))
	# A baseball cap tossed on top (generic: a dome, a button, a brim).
	var cap := tv + tb * Vector3(120, 210, 60)
	var cb2 := tb * Basis(Vector3.UP, 0.9)
	blob("fabric", Vector3(90, 62, 100), Transform3D(cb2, cap), Color(0.2, 0.3, 0.7), 12, 6)
	blob("fabric", Vector3(12, 8, 12), Transform3D(cb2, cap + Vector3(0, 62, 0)), Color(0.2, 0.3, 0.7), 6, 4)
	blob("fabric", Vector3(80, 7, 70), Transform3D(cb2 * Basis(Vector3.RIGHT, 0.15), cap + cb2 * Vector3(0, 4, 120)), Color(0.9, 0.9, 0.88), 10, 4)
	var ant := tv + tb * Vector3(0, 210, -60)
	blob("gloss", Vector3(55, 18, 40), Transform3D(tb, ant + Vector3(0, 12, 0)), Color(0.12, 0.12, 0.12), 12, 5)
	for e in [Vector3(-170, 330, -80), Vector3(120, 360, 90)]:
		var ev: Vector3 = e
		_tube(ant + Vector3(0, 20, 0), ant + ev, 3.0, Color(0.75, 0.75, 0.78), "gloss", 5)
		blob("gloss", Vector3(6, 6, 6), _at(ant + ev), Color(0.75, 0.75, 0.78), 6, 4)
	# The console on the lower shelf: a flat grey wedge, a darker lid, a cartridge in the slot,
	# power and reset buttons, a red light.
	var con := c + cb * Vector3(-20, 211, 30)
	var kb := Basis(Vector3.UP, 0.35)
	rbox("gloss", Vector3(270, 62, 200), Transform3D(kb, con + Vector3(0, 31, 0)), Color(0.7, 0.7, 0.72), 10.0)
	rbox("gloss", Vector3(260, 14, 110), Transform3D(kb, con + kb * Vector3(0, 66, -35)), Color(0.28, 0.28, 0.3), 5.0)
	for k in 4:
		box("vc", Vector3(4, 3, 60), Transform3D(kb, con + kb * Vector3(-110 + k * 10, 63, 60)), Color(0.3, 0.3, 0.32))
	cartridge(Transform3D(kb, con + kb * Vector3(0, 115, -35)), 2)
	for k in 2:
		rbox("gloss", Vector3(34, 14, 20), Transform3D(kb, con + kb * Vector3(50 + k * 50, 64, 55)), Color(0.2, 0.2, 0.22), 3.0)
	box("glow", Vector3(10, 8, 3), Transform3D(kb, con + kb * Vector3(-60, 40, 101)), Color(1.0, 0.15, 0.1))
	# Cartridges: a few stacked beside it, one on its sleeve on the floor.
	for k in 3:
		cartridge(Transform3D(Basis(Vector3.UP, 0.2 + _r.randf_range(-0.15, 0.15)) * Basis(Vector3.RIGHT, -PI * 0.5), c + cb * Vector3(200, 222 + k * 21, -60)), k + 1)
	# Controllers on the floor, cords back up to the console.
	var ports := [con + kb * Vector3(-90, 20, 100), con + kb * Vector3(-40, 20, 100)]
	for k in 2:
		var cp: Vector3 = [Vector3(-440, fy, 420), Vector3(-160, fy, 560)][k]
		var yaw: float = [0.5, -0.9][k]
		_controller(cp, yaw)
		var cpb := Basis(Vector3.UP, yaw)
		var port: Vector3 = ports[k]
		cable([cp + cpb * Vector3(0, 12, -34), cp + cpb * Vector3(-10, 4, -120) + Vector3(0, 0, 0), Vector3(port.x + 60, fy + 5, port.z + 200 - k * 60), Vector3(port.x + 20, fy + 60, port.z + 60), port], 4.0, Color(0.12, 0.12, 0.12))
	cartridge(Transform3D(Basis(Vector3.UP, 1.1) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(-320, fy + 11, 280)), 3)
	cartridge(Transform3D(Basis(Vector3.UP, -0.3) * Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.BACK, 0.1), Vector3(-560, fy + 11, 330)), 0)
	# TV cord to the wall.
	cable([tv + tb * Vector3(0, -150, -300), c + Vector3(-100, 100, -220), Vector3(-700, fy + 20, Z0 + 30), Vector3(-400, fy + 15, Z0 + 20)], 5.0, Color(0.08, 0.08, 0.08))


## A generic game controller (flat rounded slab, d-pad, two buttons, start/select) on the floor.
func _controller(p: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	rbox("gloss", Vector3(150, 24, 66), Transform3D(b, p + Vector3(0, 12, 0)), Color(0.62, 0.62, 0.65), 8.0)
	rbox("gloss", Vector3(126, 3, 44), Transform3D(b, p + b * Vector3(0, 24.5, 0)), Color(0.18, 0.18, 0.2), 1.0)
	box("gloss", Vector3(32, 6, 10), Transform3D(b, p + b * Vector3(-40, 27, 0)), Color(0.08, 0.08, 0.08))
	box("gloss", Vector3(10, 6, 32), Transform3D(b, p + b * Vector3(-40, 27, 0)), Color(0.08, 0.08, 0.08))
	for k in 2:
		cyl("gloss", 8, 8, 8, Transform3D(b, p + b * Vector3(28 + k * 22, 27, 4)), Color(0.85, 0.15, 0.15), 10)
	for k in 2:
		box("gloss", Vector3(14, 4, 5), Transform3D(b * Basis(Vector3.UP, 0.5), p + b * Vector3(-4 + k * 18, 26.5, 8)), Color(0.35, 0.35, 0.38))


# --- The bed ---------------------------------------------------------------------------------

## The bed on the right, its head against the back wall: a bookcase headboard with a bedside lamp,
## an alarm clock, books and a portable tape player; a rumpled comforter pushed down and hanging
## off the side, the pillow askew with a plush bear on it, a flannel shirt thrown across.
func _bed() -> void:
	var fy := floor_y
	var x0 := 660.0
	var x1 := 1590.0
	var bw := x1 - x0
	var cx := (x0 + x1) * 0.5
	var hz := Z0 + 190.0
	var z1 := hz + 2000.0
	var cz := (hz + z1) * 0.5
	var wood := Color(0.55, 0.36, 0.23)
	_foot(x0, Z0, x1, z1)
	# Frame: side rails, a footboard, feet.
	rbox("wood", Vector3(bw, 200, z1 - hz), _at(Vector3(cx, fy + 230, cz)), wood, 10.0, 700.0)
	rbox("wood", Vector3(bw + 20, 520, 50), _at(Vector3(cx, fy + 260, z1 + 25)), wood.darkened(0.05), 14.0, 700.0)
	for fx in [x0 + 30, x1 - 30]:
		rbox("wood", Vector3(60, 130, 60), _at(Vector3(fx, fy + 65, z1 - 30)), wood.darkened(0.15), 6.0, 300.0)
	# Bookcase headboard: a tall back, two cubbies with a divider, a top shelf.
	var hb := Vector3(cx, fy, Z0 + 95)
	rbox("wood", Vector3(bw + 40, 1000, 30), _at(hb + Vector3(0, 500, -80)), wood.darkened(0.08), 8.0, 700.0)
	rbox("wood", Vector3(bw + 40, 30, 190), _at(hb + Vector3(0, 1000, 0)), wood.lightened(0.05), 8.0, 700.0)
	rbox("wood", Vector3(bw + 40, 30, 190), _at(hb + Vector3(0, 700, 0)), wood, 8.0, 700.0)
	for sx in [-bw * 0.5 - 5, -bw * 0.1, bw * 0.5 + 5]:
		rbox("wood", Vector3(30, 300, 190), _at(hb + Vector3(sx, 850, 0)), wood, 6.0, 700.0)
	rbox("wood", Vector3(bw + 40, 460, 190), _at(hb + Vector3(0, 470, 0)), wood.darkened(0.12), 8.0, 700.0)
	sticker(0, _at(hb + Vector3(-bw * 0.3, 560, 96)), 30.0)
	sticker(4, _at(hb + Vector3(bw * 0.25, 610, 96)), 34.0)
	sticker(2, Transform3D(Basis(Vector3.BACK, 0.2), hb + Vector3(-bw * 0.05, 420, 96)), 28.0)
	# In the cubbies: books (left), a portable tape player with headphones and tapes (right).
	var cy := fy + 715.0
	var bxx := hb.x - bw * 0.5 + 20
	var bcols := [Color(0.2, 0.3, 0.6), Color(0.75, 0.25, 0.2), Color(0.9, 0.8, 0.3), Color(0.3, 0.55, 0.4), Color(0.9, 0.9, 0.85)]
	while bxx < hb.x - bw * 0.12 - 60:
		var t := _r.randf_range(22, 45)
		book(Vector3(t, _r.randf_range(170, 250), 150), Transform3D(Basis(Vector3.BACK, _r.randf_range(-0.05, 0.05)), Vector3(bxx + t * 0.5, cy, hb.z + 10)), _jit(bcols[_r.randi() % bcols.size()], 0.12), _r.randi() % 20)
		bxx += t + 1.5
	book(Vector3(34, 220, 150), Transform3D(Basis(Vector3.BACK, -0.45), Vector3(bxx + 60, cy, hb.z + 10)), Color(0.5, 0.25, 0.55), 3)
	var wp := hb + Vector3(bw * 0.15, 715, 20)
	rbox("gloss", Vector3(130, 36, 90), _at(wp + Vector3(0, 18, 0), -0.2), Color(0.12, 0.35, 0.6), 6.0)
	box("gloss", Vector3(80, 3, 50), Transform3D(Basis(Vector3.UP, -0.2), wp + Vector3(0, 37, 0)), Color(0.3, 0.32, 0.35))
	cable([wp + Vector3(60, 20, 30), wp + Vector3(120, 5, 60), wp + Vector3(170, 20, 40)], 2.5, Color(0.1, 0.1, 0.1))
	var hp := wp + Vector3(200, 0, 20)
	for s in [-1.0, 1.0]:
		cyl("fabric", 34, 34, 18, Transform3D(Basis(Vector3.FORWARD, PI * 0.5 + s * 0.3), hp + Vector3(s * 70, 34, 0)), Color(0.95, 0.55, 0.2), 12)
	cable([hp + Vector3(-70, 50, 0), hp + Vector3(-40, 100, 0), hp + Vector3(40, 100, 0), hp + Vector3(70, 50, 0)], 5.0, Color(0.6, 0.6, 0.62))
	for k in 3:
		cassette(hp + Vector3(170 + _r.randf_range(-10, 10), k * 17, -20), _r.randf_range(-0.3, 0.3), (k + 1) % 4)
	# On top: the bedside lamp (lit), the alarm clock with red digits, a glass of water, a comic.
	var ty := fy + 1015.0
	var lp := Vector3(x0 + 130, ty, hb.z)
	cyl("gloss", 60, 70, 24, _at(lp + Vector3(0, 12, 0)), Color(0.85, 0.82, 0.75), 16)
	cyl("gloss", 14, 14, 200, _at(lp + Vector3(0, 120, 0)), Color(0.85, 0.82, 0.75), 10)
	blob("gloss", Vector3(55, 70, 55), _at(lp + Vector3(0, 80, 0)), Color(0.85, 0.5, 0.35), 14, 8)
	cyl("glow", 112, 74, 135, _at(lp + Vector3(0, 240, 0)), Color(0.72, 0.47, 0.28), 18, false)
	_lining(110, 72, 133, _at(lp + Vector3(0, 240, 0)), Color(1.0, 0.88, 0.66), 18)
	blob("glow", Vector3(30, 36, 30), _at(lp + Vector3(0, 205, 0)), Color(1.0, 0.95, 0.8), 8, 5)
	var ck := Vector3(x0 + 380, ty, hb.z + 20)
	var kb := Basis(Vector3.UP, -0.35)
	rbox("gloss", Vector3(170, 80, 80), Transform3D(kb, ck + Vector3(0, 40, 0)), Color(0.12, 0.1, 0.1), 12.0)
	_print("clock", Transform3D(kb, ck + kb * Vector3(0, 42, 41)), Vector2(130, 46), Color(1.0, 1.0, 1.0), "glow")
	cyl("gloss", 30, 34, 110, _at(Vector3(x0 + 560, ty + 55, hb.z + 20)), Color(0.75, 0.88, 0.95), 12)
	comic(Vector3(x0 + 740, ty, hb.z + 10), 0.3, 1)
	# Mattress and fitted sheet.
	var mt := fy + 520.0
	rbox("fabric", Vector3(bw - 40, 190, z1 - hz - 30), _at(Vector3(cx, mt - 95, cz - 5)), Color(0.72, 0.84, 0.92), 40.0, 400.0)
	# Pillow, askew and dented, and the plush bear sitting against the headboard.
	blob("fabric", Vector3(320, 70, 200), Transform3D(Basis(Vector3.UP, 0.12) * Basis(Vector3.FORWARD, 0.06), Vector3(cx + 40, mt + 55, hz + 250)), Color(0.96, 0.95, 0.9), 16, 8, 0.6, 0.35)
	_bear(Vector3(x0 + 230, mt + 30, hz + 150), 0.5)
	# The comforter: pushed down toward the foot, hanging over the room side.
	_comforter(Vector3(cx, mt, cz + 260), bw - 40, 1500.0)
	# A flannel shirt thrown across the bed, one sleeve hanging.
	cloth("fabric", Vector2(420, 360), Transform3D(Basis(Vector3.UP, 0.7), Vector3(cx - 150, mt + 95, hz + 700)), Color(0.3, 0.55, 0.45), 26.0, 0.0, 10, 3.0, 8.0, "tee")
	drape(Transform3D(Basis(Vector3.UP, -PI * 0.5 + 0.2), Vector3(x0 + 10, mt + 70, hz + 860)), 120.0, 60.0, 330.0, Color(0.28, 0.52, 0.42), 30.0, 0.3, "fabric", 5)
	# An open magazine on the bed.
	comic(Vector3(cx + 180, mt + 110, cz + 300), -0.4, 2, "magazines", true)


## The comforter: the top a lumpy sheet over the mattress, folding down over the room-side edge and
## the foot, with its folded-back head end as a roll.
func _comforter(c: Vector3, mw: float, length: float) -> void:
	var fy := floor_y
	var drop := c.y - fy - 60.0
	var hang_l := 420.0
	var hang_f := 300.0
	var W := mw + hang_l + 60.0
	var L := length + hang_f
	var nu := 22
	var nv := 22
	var rows := []
	var uvs := []
	for j in nv + 1:
		var row := []
		var urow := []
		for i in nu + 1:
			var u := float(i) / nu
			var v := float(j) / nv
			# Unfolded coordinates: X across (the room side is negative), Z along (the foot negative).
			var X := -mw * 0.5 - hang_l + u * W
			var Z := -length * 0.5 - hang_f + v * L
			var w := sin(X * 0.011 + Z * 0.004) * 0.6 + sin(Z * 0.013 - X * 0.006 + 1.3) * 0.4 + sin(X * 0.03 + Z * 0.02) * 0.15
			var x := X
			var z := Z
			var y := 40.0 + 30.0 * w
			var r := 70.0
			var ex := -mw * 0.5 - X
			if ex > 0.0:
				var a := minf(ex / r, PI * 0.5)
				var rest := maxf(0.0, ex - r * PI * 0.5)
				x = -mw * 0.5 - r * sin(a) - rest * 0.12 - 30.0 * sin(Z * 0.02) * smoothstep(0.0, 200.0, rest)
				y = 40.0 - r * (1.0 - cos(a)) - rest + 20.0 * w
			var ez := -length * 0.5 - Z
			if ez > 0.0:
				var a2 := minf(ez / r, PI * 0.5)
				var rest2 := maxf(0.0, ez - r * PI * 0.5)
				z = -length * 0.5 - r * sin(a2) - rest2 * 0.1 - 25.0 * sin(X * 0.02) * smoothstep(0.0, 200.0, rest2)
				y = minf(y, 40.0 - r * (1.0 - cos(a2)) - rest2 + 20.0 * w)
				if ex > 0.0:
					y -= 30.0
			y = maxf(y, -drop)
			row.append(Vector3(x, y, z))
			urow.append(Vector2(u * 3.2, v * 3.2))
		rows.append(row)
		uvs.append(urow)
	var xf := _at(c, 0.04)
	_surf("blanket", "", rows, uvs, xf, Color(1, 1, 1), Vector3(0, -300, 0), false, 30.0)
	# The folded-back head end: a soft roll.
	var rr := []
	var ru := []
	for j in 7:
		var row := []
		var urow := []
		var v := float(j) / 6.0
		var a := v * PI * 1.2 - PI * 0.1
		for i in 13:
			var u := float(i) / 12.0
			var X := -mw * 0.5 - 60 + u * (mw + 60)
			var Z := length * 0.5 - 10.0 + 20.0 * sin(X * 0.01)
			row.append(Vector3(X, 40.0 + 40.0 * sin(a) + 12.0 * sin(X * 0.03), Z + 55.0 * cos(a) - 30.0))
			urow.append(Vector2(u * 2.0, v * 0.3))
		rr.append(row)
		ru.append(urow)
	_surf("blanket", "", rr, ru, xf, Color(0.95, 0.95, 0.95), Vector3(0, 0, length * 0.5 - 60.0))


## A plush bear (generic): blobs for body, head, ears, snout, arms and legs.
func _bear(p: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -0.25)
	var fur := Color(0.72, 0.5, 0.32)
	blob("fabric", Vector3(85, 100, 75), Transform3D(b, p + b * Vector3(0, 90, 0)), fur, 12, 8)
	blob("fabric", Vector3(72, 66, 64), Transform3D(b, p + b * Vector3(0, 225, 0)), fur, 12, 8)
	for s in [-1.0, 1.0]:
		blob("fabric", Vector3(24, 24, 14), Transform3D(b, p + b * Vector3(s * 52, 280, 0)), fur.darkened(0.1), 8, 5)
		blob("fabric", Vector3(28, 60, 28), Transform3D(b * Basis(Vector3.BACK, s * 0.5), p + b * Vector3(s * 88, 110, 20)), fur, 8, 6)
		blob("fabric", Vector3(32, 30, 70), Transform3D(b, p + b * Vector3(s * 48, 20, 70)), fur, 8, 6)
		blob("gloss", Vector3(8, 8, 6), Transform3D(b, p + b * Vector3(s * 24, 240, 58)), Color(0.05, 0.04, 0.04), 6, 4)
	blob("fabric", Vector3(30, 22, 24), Transform3D(b, p + b * Vector3(0, 205, 58)), Color(0.9, 0.8, 0.65), 8, 5)
	blob("gloss", Vector3(9, 7, 6), Transform3D(b, p + b * Vector3(0, 215, 80)), Color(0.08, 0.05, 0.05), 6, 4)
	blob("fabric", Vector3(60, 18, 50), Transform3D(b * Basis(Vector3.BACK, 0.1), p + b * Vector3(0, 175, 10)), Color(0.8, 0.2, 0.25), 10, 4)


# --- Bookshelf, desk, the rest of the room ---------------------------------------------------

## A tall bookshelf against the left wall in the back corner: rows of books of every height and
## colour (some leaning, some lying), board games, tapes, comics, keepsakes.
func _bookshelf() -> void:
	var fy := floor_y
	var d := 300.0
	var sx := X0 + d * 0.5 + 8
	var za := Z0 + 10
	var zb := Z0 + 740
	var zc := (za + zb) * 0.5
	var wood := Color(0.66, 0.47, 0.3)
	var hgt := 1780.0
	_foot(X0, za, X0 + d, zb)
	for z in [za + 10, zb - 10]:
		rbox("wood", Vector3(d, hgt, 20), _at(Vector3(sx, fy + hgt * 0.5, z)), wood, 4.0, 700.0)
	box("wood", Vector3(8, hgt, zb - za), _at(Vector3(X0 + 12, fy + hgt * 0.5, zc)), wood.darkened(0.3), 700.0)
	rbox("wood", Vector3(d + 10, 24, zb - za + 16), _at(Vector3(sx + 5, fy + hgt, zc)), wood.lightened(0.05), 5.0, 700.0)
	rbox("wood", Vector3(d - 10, 70, zb - za - 20), _at(Vector3(sx + 5, fy + 35, zc)), wood.darkened(0.12), 4.0, 700.0)
	var cols := [Color(0.78, 0.22, 0.2), Color(0.22, 0.4, 0.75), Color(0.92, 0.78, 0.25), Color(0.3, 0.6, 0.38), Color(0.55, 0.3, 0.62),
			Color(0.9, 0.5, 0.2), Color(0.15, 0.15, 0.18), Color(0.92, 0.9, 0.84), Color(0.4, 0.25, 0.15)]
	var levels := [fy + 70, fy + 440, fy + 800, fy + 1150, fy + 1470]
	for s in levels.size():
		var y: float = levels[s]
		if s > 0:
			rbox("wood", Vector3(d - 10, 22, zb - za - 20), _at(Vector3(sx + 5, y - 11, zc)), wood, 4.0, 700.0)
		var z := za + 24.0
		var zend := zb - 24.0
		if s == 0:
			# Board games and a shoebox lying stacked, magazines.
			var yy := y
			for k in 3:
				var gs := Vector3(260 - k * 20, 55 - k * 8, 380 - k * 30)
				var gb := Basis(Vector3.UP, _r.randf_range(-0.05, 0.05))
				rbox("vc", gs, Transform3D(gb, Vector3(sx + 10, yy + gs.y * 0.5, z + 200)), [Color(0.2, 0.4, 0.8), Color(0.85, 0.3, 0.25), Color(0.95, 0.85, 0.3)][k], 2.0)
				_print("boardgame", Transform3D(gb * Basis(Vector3.UP, PI * 0.5), Vector3(sx + 10 + gs.x * 0.5 + 0.5, yy + gs.y * 0.5, z + 200)), Vector2(gs.z - 10, gs.y - 6))
				yy += gs.y
			book_stack(Vector3(sx + 20, y, zend - 150), 6, PI * 0.5, [Color(0.9, 0.3, 0.3), Color(0.3, 0.5, 0.9), Color(0.95, 0.9, 0.8)], 200, 270, 8)
		elif s == 2:
			# Tapes standing in a row, then comics lying in a stack, a trophy.
			for k in 9:
				cassette(Vector3(sx + 80, y + 36, z + 10 + k * 19), 0.0, k % 4, true, PI * 0.5)
			book_stack(Vector3(sx + 20, y, z + 330), 9, PI * 0.5, [Color(0.95, 0.35, 0.3), Color(0.3, 0.45, 0.9), Color(0.95, 0.85, 0.3), Color(0.4, 0.75, 0.4)], 170, 260, 4)
			var tp := Vector3(sx + 20, y, zend - 60)
			cyl("gloss", 45, 50, 30, _at(tp + Vector3(0, 15, 0)), Color(0.15, 0.15, 0.18), 12)
			cyl("gloss", 8, 8, 80, _at(tp + Vector3(0, 70, 0)), Color(0.9, 0.75, 0.3), 8)
			blob("gloss", Vector3(28, 28, 28), _at(tp + Vector3(0, 130, 0)), Color(0.9, 0.75, 0.3), 10, 6)
		elif s == 4:
			# The top shelf: a globe and a stuffed rabbit-ish plush, a few big books lying.
			var gp := Vector3(sx + 10, y, z + 120)
			cyl("wood", 55, 65, 20, _at(gp + Vector3(0, 10, 0)), Color(0.3, 0.2, 0.12), 12)
			_tube(gp + Vector3(0, 20, 0), gp + Vector3(0, 70, 0), 6.0, Color(0.8, 0.7, 0.4))
			blob("gloss", Vector3(115, 115, 115), Transform3D(Basis(Vector3.BACK, 0.4), gp + Vector3(0, 185, 0)), Color(0.3, 0.55, 0.8), 14, 9)
			for k in 3:
				blob("vc", Vector3(40, 30, 50), _at(gp + Vector3(0, 185, 0) + Vector3(0, 60 - k * 55, 0).rotated(Vector3.FORWARD, 0.4) + Vector3(90 * (0.2 + k * 0.2), 0, (k - 1) * 30)), Color(0.45, 0.65, 0.35), 8, 5)
			book_stack(Vector3(sx + 20, y, zend - 150), 3, PI * 0.5, cols, 220, 290, 35)
		else:
			_book_row(s, y, z, zend, za, zc, sx, d, cols)


## One shelf's row of books, a few leaning, a gap or two.
func _book_row(s: int, y: float, z: float, zend: float, za: float, zc: float, sx: float, d: float, cols: Array) -> void:
	# Rows of books.
	var guard := 0
	while z < zend - 30 and guard < 40:
		guard += 1
		var t := _r.randf_range(22, 55)
		var bh := _r.randf_range(190, 300)
		var dep := _r.randf_range(160, 230)
		var tilt := 0.0
		if _r.randf() < 0.12 and z > za + 100:
			tilt = _r.randf_range(0.15, 0.3)
		var bb := Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.BACK, -tilt)
		book(Vector3(t, bh, dep), Transform3D(bb, Vector3(X0 + 20 + dep * 0.5 + (d - 20 - dep), y, z + t * 0.5 + (bh * sin(tilt) if tilt > 0 else 0.0))), _jit(cols[_r.randi() % cols.size()], 0.14), _r.randi() % 20)
		z += t + 1.0 + (bh * sin(tilt) * 1.1 if tilt > 0 else 0.0)
		if s == 1 and z > zc - 20 and z < zc + 40:
			# A gap with the dinosaur in it.
			_dino(Vector3(sx + 30, y, z + 110), PI * 0.5 + 0.3, 0.8, Color(0.85, 0.5, 0.2))
			z += 240.0
		if s == 3 and _r.randf() < 0.08:
			z += 90.0


## The desk against the left wall: a drawer pedestal, a lit desk lamp, homework, an open notebook,
## pencils, a pencil cup, textbooks, a boombox and tapes, a calculator, a mug; a corkboard and a
## pennant above; the chair pulled out with a hoodie over it; the backpack slumped by it.
func _desk() -> void:
	var fy := floor_y
	var za := 700.0
	var zb := 1700.0
	var xd := X0 + 620.0
	var top := fy + 740.0
	var wood := Color(0.64, 0.46, 0.3)
	var cx := (X0 + xd) * 0.5
	_foot(X0, za, xd, za + 420)
	_foot(xd - 60, zb - 60, xd, zb)
	_foot(X0, zb - 60, X0 + 60, zb)
	rbox("wood", Vector3(xd - X0 + 20, 32, zb - za), _at(Vector3(cx, top - 16, (za + zb) * 0.5)), wood, 6.0, 700.0)
	rbox("wood", Vector3(xd - X0 - 20, top - 32 - fy, 420), _at(Vector3(cx, fy + (top - 32 - fy) * 0.5, za + 210)), wood.darkened(0.08), 6.0, 700.0)
	for k in 3:
		var dy := fy + 110 + k * 205
		rbox("wood", Vector3(20, 185, 390), _at(Vector3(xd, dy, za + 210)), wood.lightened(0.08), 5.0, 700.0)
		rbox("gloss", Vector3(10, 18, 90), _at(Vector3(xd + 15, dy + 50, za + 210)), Color(0.78, 0.62, 0.3), 3.0)
	sticker(6, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(xd + 10.6, fy + 520, za + 120)), 30.0)
	for lz in [zb - 30]:
		for lx in [X0 + 40, xd - 40]:
			rbox("wood", Vector3(44, top - 32 - fy, 44), _at(Vector3(lx, fy + (top - 32 - fy) * 0.5, lz)), wood.darkened(0.1), 5.0, 700.0)
	box("wood", Vector3(16, 400, zb - za - 440), _at(Vector3(X0 + 30, top - 232, za + 420 + (zb - za - 440) * 0.5)), wood.darkened(0.2), 700.0)
	# The lamp: a heavy base, a jointed arm, a cone shade glowing inside.
	var lb := Vector3(X0 + 110, top, za + 120)
	# (DESK_LAMP in _lights is this lamp's bulb.)
	cyl("gloss", 70, 80, 30, _at(lb + Vector3(0, 15, 0)), Color(0.15, 0.3, 0.6), 16)
	var j1 := lb + Vector3(40, 330, 60)
	var j2 := lb + Vector3(210, 420, 150)
	_tube(lb + Vector3(0, 28, 0), j1, 9.0, Color(0.15, 0.3, 0.6), "gloss", 8)
	_tube(j1, j2, 9.0, Color(0.15, 0.3, 0.6), "gloss", 8)
	blob("gloss", Vector3(16, 16, 16), _at(j1), Color(0.15, 0.3, 0.6), 8, 5)
	var sd := Vector3(0.5, -1.0, 0.35).normalized()
	var sside := sd.cross(Vector3.UP).normalized()
	var sb := Basis(sside, -sd, sside.cross(-sd))
	cyl("gloss", 110, 45, 150, Transform3D(sb, j2 + sd * 40), Color(0.15, 0.3, 0.6), 16, false)
	_lining(108, 43, 148, Transform3D(sb, j2 + sd * 40), Color(0.95, 0.92, 0.85))
	blob("glow", Vector3(34, 34, 34), _at(j2 + sd * 70), Color(1.0, 0.92, 0.7), 10, 6)
	# Papers, the open notebook, pencils.
	_print("homework", Transform3D(Basis(Vector3.UP, 0.25) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(cx + 90, top + 1, za + 460)), Vector2(215, 280))
	_print("note_paper", Transform3D(Basis(Vector3.UP, -0.5) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(cx + 150, top + 1.6, za + 650)), Vector2(215, 270))
	var nb := Basis(Vector3.UP, PI * 0.5 - 0.12)
	box("vc", Vector3(500, 8, 330), Transform3D(nb, Vector3(cx + 20, top + 4, za + 800)), Color(0.08, 0.08, 0.08))
	for s in [-1.0, 1.0]:
		var pb := nb * Basis(Vector3.FORWARD, s * 0.04)
		_print("white", Transform3D(pb * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(cx + 20, top + 11, za + 800) + nb * Vector3(s * 122, 0, 0)), Vector2(236, 316), Color(0.97, 0.96, 0.92))
	_print("note_paper", Transform3D(nb * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(cx + 20, top + 11.8, za + 800) + nb * Vector3(122, 0, 0)), Vector2(222, 300), Color.WHITE, "atlas", Rect2(0, 0.02, 1, 0.55))
	_print("homework", Transform3D(nb * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(cx + 20, top + 11.8, za + 800) + nb * Vector3(-122, 0, 0)), Vector2(222, 300), Color.WHITE, "atlas", Rect2(0, 0.45, 1, 0.55))
	var pcols := [Color(0.95, 0.8, 0.2), Color(0.9, 0.3, 0.3), Color(0.3, 0.6, 0.9), Color(0.95, 0.8, 0.2)]
	for k in 4:
		var a := Vector3(cx + 180 + k * 18, top + 5, za + 950 + k * 30)
		pencil(a, a + Vector3(-60 + k * 30, 0, 150 - k * 20), pcols[k], k == 2)
	box("vc", Vector3(50, 12, 22), _at(Vector3(cx + 230, top + 6, za + 560), 0.4), Color(0.95, 0.6, 0.65))
	# Pencil cup, textbooks, calculator, mug.
	var pc := Vector3(X0 + 80, top, za + 330)
	cyl("gloss", 38, 34, 110, _at(pc + Vector3(0, 55, 0)), Color(0.9, 0.85, 0.3), 14)
	for k in 5:
		var a := TAU * k / 5.0
		pencil(pc + Vector3(cos(a) * 15, 20, sin(a) * 15), pc + Vector3(cos(a) * 50, 190, sin(a) * 45), pcols[k % 4], k == 1)
	book_stack(Vector3(cx - 60, top, zb - 170), 3, 0.2, [Color(0.2, 0.35, 0.7), Color(0.7, 0.2, 0.2), Color(0.25, 0.55, 0.3)], 230, 300, 38)
	var calc := Vector3(cx + 200, top, zb - 220)
	rbox("gloss", Vector3(90, 14, 150), _at(calc + Vector3(0, 7, 0), 0.3), Color(0.12, 0.12, 0.14), 4.0)
	box("glow", Vector3(60, 2, 26), _at(calc + Basis(Vector3.UP, 0.3) * Vector3(0, 15, -48), 0.3), Color(0.6, 0.7, 0.55))
	for k in 12:
		box("vc", Vector3(16, 3, 14), _at(calc + Basis(Vector3.UP, 0.3) * Vector3(-27 + (k % 3) * 27, 15, -10 + (k / 3) * 20), 0.3), Color(0.7, 0.7, 0.72))
	var mug := Vector3(cx + 180, top, za + 280)
	cyl("gloss", 40, 40, 100, _at(mug + Vector3(0, 50, 0)), Color(0.9, 0.35, 0.3), 14)
	cyl("vc", 36, 36, 2, _at(mug + Vector3(0, 90, 0)), Color(0.25, 0.15, 0.08), 12)
	cable([mug + Vector3(38, 80, 0), mug + Vector3(65, 60, 0), mug + Vector3(40, 25, 0)], 7.0, Color(0.9, 0.35, 0.3))
	# The boombox (generic): a long body, two speakers, a tape door, dials, a handle.
	var bb := Vector3(X0 + 110, top + 110, zb - 380)
	var bbb := Basis(Vector3.UP, PI * 0.5 + 0.1)
	rbox("gloss", Vector3(400, 200, 110), Transform3D(bbb, bb), Color(0.16, 0.16, 0.18), 14.0)
	for s in [-1.0, 1.0]:
		cyl("gloss", 72, 72, 8, Transform3D(bbb * Basis(Vector3.RIGHT, PI * 0.5), bb + bbb * Vector3(s * 125, -12, 56)), Color(0.55, 0.55, 0.58), 18)
		cyl("vc", 55, 30, 14, Transform3D(bbb * Basis(Vector3.RIGHT, PI * 0.5), bb + bbb * Vector3(s * 125, -12, 60)), Color(0.08, 0.08, 0.08), 16)
	rbox("gloss", Vector3(120, 76, 8), Transform3D(bbb, bb + bbb * Vector3(0, -10, 56)), Color(0.35, 0.37, 0.4), 3.0)
	box("glow", Vector3(100, 14, 2), Transform3D(bbb, bb + bbb * Vector3(0, 60, 56)), Color(0.4, 0.9, 0.6))
	cable([bb + bbb * Vector3(-170, 100, 0), bb + bbb * Vector3(-150, 150, 0), bb + bbb * Vector3(150, 150, 0), bb + bbb * Vector3(170, 100, 0)], 10.0, Color(0.6, 0.6, 0.62))
	for k in 5:
		cassette(Vector3(X0 + 100 + _r.randf_range(-8, 8), top + k * 17, zb - 110), PI * 0.5 + _r.randf_range(-0.3, 0.3), k % 4)
	cassette(Vector3(cx + 60, top, zb - 480), 0.9, 2, false)
	# The desk lamp's warm light.
	# Corkboard, notes and photos pinned to it; a pennant above.
	var cz := 1180.0
	var wy := 420.0
	var wb := Basis(Vector3.UP, PI * 0.5)
	rbox("wood", Vector3(820, 580, 16), Transform3D(wb, Vector3(X0 + 10, wy, cz)), Color(0.55, 0.38, 0.22), 6.0, 400.0)
	_print("cork", Transform3D(wb, Vector3(X0 + 18.5, wy, cz)), Vector2(780, 540))
	var pins := []
	var items := [["note_paper", Vector3(0, 40, -220), Vector2(200, 250), 0.08], ["homework", Vector3(0, -30, 180), Vector2(170, 220), -0.1],
			["drawing", Vector3(0, 150, -10), Vector2(170, 128), 0.05], ["calendar", Vector3(0, -130, -20), Vector2(150, 200), -0.04]]
	for it in items:
		var o: Vector3 = it[1]
		var sz2: Vector2 = it[2]
		_print(it[0], Transform3D(wb * Basis(Vector3.BACK, it[3]), Vector3(X0 + 20 + pins.size() * 0.4, wy + o.y, cz + o.z)), sz2)
		pins.append(Vector3(X0 + 24, wy + o.y + sz2.y * 0.5 - 15, cz + o.z))
	for k in 2:
		var ph := Vector3(X0 + 22 + k * 0.4, wy + 160 - k * 40, cz + 250 + k * 30)
		_print("white", Transform3D(wb * Basis(Vector3.BACK, 0.12 - k * 0.25), ph), Vector2(110, 130), Color(0.97, 0.97, 0.95))
		_print("window", Transform3D(wb * Basis(Vector3.BACK, 0.12 - k * 0.25), ph + Vector3(0.4, 10, 0)), Vector2(94, 94), Color.WHITE, "atlas", Rect2(0.1 + k * 0.4, 0.3, 0.4, 0.5))
		pins.append(ph + Vector3(2, 55, 0))
	for p in pins:
		var pv: Vector3 = p
		cyl("gloss", 8, 8, 12, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), pv + Vector3(4, 0, 0)), [Color(0.9, 0.2, 0.2), Color(0.2, 0.5, 0.9), Color(0.95, 0.85, 0.2)][_r.randi() % 3], 8)
	# The pennant, pointing toward the window.
	var pn := Vector3(X0 + 12, 900, 1000)
	var pw := 620.0
	_emit("atlas", "pennant", [pn + Vector3(0, 110, pw * 0.5), pn + Vector3(0, -110, pw * 0.5), pn + Vector3(0, -8, -pw * 0.5)],
			[Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT], [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0.55)], Color.WHITE)
	cyl("gloss", 6, 6, 12, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), pn + Vector3(4, 90, pw * 0.5 - 20)), Color(0.9, 0.2, 0.2), 8)
	# The chair, pulled out and turned, with a hoodie thrown over its back.
	var ch := Vector3(-790, fy, 1250)
	var chb := Basis(Vector3.UP, -PI * 0.5 + 0.5)
	_foot(ch.x - 230, ch.z - 230, ch.x + 230, ch.z + 230)
	rbox("wood", Vector3(420, 36, 400), Transform3D(chb, ch + Vector3(0, 450, 0)), Color(0.5, 0.33, 0.2), 10.0, 500.0)
	for lx in [-180.0, 180.0]:
		for lz in [-170.0, 170.0]:
			cyl("wood", 18, 14, 440, Transform3D(chb, ch + chb * Vector3(lx, 220, lz)), Color(0.48, 0.32, 0.2), 8)
	for lx in [-180.0, 180.0]:
		cyl("wood", 16, 16, 460, Transform3D(chb, ch + chb * Vector3(lx, 690, 185)), Color(0.48, 0.32, 0.2), 8)
	for yy in [640.0, 860.0]:
		rbox("wood", Vector3(400, 60, 26), Transform3D(chb, ch + chb * Vector3(0, yy, 190)), Color(0.5, 0.33, 0.2), 8.0, 500.0)
	var hood := Transform3D(chb, ch + chb * Vector3(0, 895, 190))
	drape(hood, 380.0, 360.0, 300.0, Color(0.72, 0.18, 0.22), 24.0, 0.3, "fabric", 8, 12.0)
	for s in [-1.0, 1.0]:
		drape(Transform3D(chb * Basis(Vector3.UP, PI * 0.5), ch + chb * Vector3(s * 200, 880, 190)), 110.0, 20.0, 380.0, Color(0.7, 0.17, 0.2), 20.0, 0.2, "fabric", 6, 10.0)
	blob("fabric", Vector3(150, 60, 70), Transform3D(chb, ch + chb * Vector3(0, 900, 260)), Color(0.66, 0.15, 0.2), 10, 6)
	# The backpack slumped against the pedestal, a notebook sliding out.
	var bp := Vector3(xd + 150, fy, za + 250)
	var bpb := Basis(Vector3.UP, 0.3) * Basis(Vector3.FORWARD, -0.25)
	blob("fabric", Vector3(170, 220, 100), Transform3D(bpb, bp + Vector3(0, 200, 0)), Color(0.2, 0.52, 0.5), 12, 8, 0.6, 0.55)
	blob("fabric", Vector3(130, 90, 50), Transform3D(bpb, bp + bpb * Vector3(0, -40, 90) + Vector3(0, 200, 0)), Color(0.18, 0.45, 0.43), 10, 6, 0.6, 0.55)
	for s in [-1.0, 1.0]:
		cable([bp + bpb * Vector3(s * 80, 200, -95) + Vector3(0, 200, 0), bp + bpb * Vector3(s * 90, 0, -140) + Vector3(0, 200, 0), bp + Vector3(s * 60, 10, -150)], 16.0, Color(0.12, 0.12, 0.13), "fabric", 3)
	var nbk := Basis(Vector3.UP, 0.8) * Basis(Vector3.RIGHT, -PI * 0.5)
	box("vc", Vector3(190, 250, 10), Transform3D(nbk, bp + Vector3(210, 6, 110)), Color(0.95, 0.94, 0.9))
	_print("notebook", Transform3D(nbk, bp + Vector3(210, 11.2, 110)), Vector2(190, 250))


## The front of the room (behind the view): the window with its dusk sky, blinds and curtains; the
## door with a jacket on its hook; a beanbag, a toy chest and a laundry pile; the space poster.
func _front_of_room() -> void:
	var fy := floor_y
	# Window on the right wall, over the bed's foot.
	var wz := 1100.0
	var wy := fy + 1400.0
	var ww := 1000.0
	var wh := 900.0
	var wl := Basis(Vector3.UP, -PI * 0.5)
	_print("window", Transform3D(wl, Vector3(X1 - 22, wy, wz)), Vector2(ww - 80, wh - 80), Color(0.9, 0.9, 0.95), "glow")
	for f in [[Vector3(40, wh, 60), Vector3(X1 - 30, wy, wz - ww * 0.5)], [Vector3(40, wh, 60), Vector3(X1 - 30, wy, wz + ww * 0.5)],
			[Vector3(40, 60, ww + 60), Vector3(X1 - 30, wy + wh * 0.5, wz)], [Vector3(120, 36, ww + 120), Vector3(X1 - 60, wy - wh * 0.5 - 10, wz)],
			[Vector3(30, wh, 30), Vector3(X1 - 30, wy, wz)], [Vector3(30, 30, ww), Vector3(X1 - 30, wy + 60, wz)]]:
		rbox("wood", f[0], _at(f[1]), Color(0.93, 0.92, 0.88), 6.0, 900.0)
	# Mini blinds, mostly raised, a few slats hanging crooked.
	for k in 14:
		var tilt := 1.1 if k < 11 else 0.4 + k * 0.05
		box("gloss", Vector3(14, 3, ww - 60), Transform3D(Basis(Vector3.FORWARD, tilt) * Basis(Vector3.RIGHT, (0.05 if k == 13 else 0.0)), Vector3(X1 - 70, wy + wh * 0.5 - 50 - k * (9 if k < 11 else 40), wz)), Color(0.9, 0.88, 0.82))
	rbox("gloss", Vector3(24, 30, ww - 50), _at(Vector3(X1 - 70, wy + wh * 0.5 - 40, wz)), Color(0.9, 0.88, 0.82), 4.0)
	_tube(Vector3(X1 - 60, wy + wh * 0.5 - 40, wz + ww * 0.5 - 60), Vector3(X1 - 60, wy - 100, wz + ww * 0.5 - 60), 2.0, Color(0.9, 0.88, 0.82))
	# Curtains: pleated panels either side of the window from a rod.
	_tube(Vector3(X1 - 90, wy + wh * 0.5 + 90, wz - ww * 0.5 - 350), Vector3(X1 - 90, wy + wh * 0.5 + 90, wz + ww * 0.5 + 350), 12.0, Color(0.75, 0.62, 0.35))
	for side in [-1.0, 1.0]:
		var rows := []
		var uvs := []
		var cw := 380.0
		for j in 9:
			var row := []
			var urow := []
			var v := j / 8.0
			for i in 17:
				var u := i / 16.0
				var gather := 1.0 - 0.35 * sin(v * PI * 0.9)
				var z: float = wz + side * (ww * 0.5 + 300.0 - u * cw * gather)
				var x := X1 - 95 - 18.0 * sin(u * PI * 8.0) - 20.0 * v
				row.append(Vector3(x, wy + wh * 0.5 + 80 - v * (wh + 380), z))
				urow.append(Vector2(u * 3.0, v * 4.0))
			rows.append(row)
			uvs.append(urow)
		_surf("fabric", "", rows, uvs, Transform3D(), Color(0.3, 0.42, 0.72), Vector3(X1 + 100000, wy, wz), false, 4.0)
	# The door on the front wall, a jacket on the hook beside it.
	var dx := -450.0
	rbox("vc", Vector3(840, 2040, 40), _at(Vector3(dx, fy + 1020, Z1 - 30)), Color(0.93, 0.9, 0.84), 10.0)
	for k in 2:
		rbox("vc", Vector3(600, 820, 12), _at(Vector3(dx, fy + 520 + k * 960, Z1 - 55)), Color(0.9, 0.87, 0.8), 14.0)
	blob("gloss", Vector3(30, 30, 30), _at(Vector3(dx + 330, fy + 1000, Z1 - 80)), Color(0.8, 0.66, 0.3), 10, 6)
	sticker(3, Transform3D(Basis(Vector3.UP, PI), Vector3(dx - 150, fy + 1400, Z1 - 62)), 40.0)
	sticker(0, Transform3D(Basis(Vector3.UP, PI), Vector3(dx + 100, fy + 1500, Z1 - 62)), 36.0)
	rbox("gloss", Vector3(30, 30, 60), _at(Vector3(-1100, fy + 1600, Z1 - 30)), Color(0.8, 0.66, 0.3), 5.0)
	drape(Transform3D(Basis(Vector3.UP, PI), Vector3(-1100, fy + 1600, Z1 - 70)), 360.0, 700.0, 640.0, Color(0.2, 0.3, 0.55), 22.0, 0.3, "fabric", 7, 14.0)
	# The space poster on the wall by the door.
	_print("poster_space", Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.BACK, 0.03), Vector3(500, fy + 1400, Z1 - 12)), Vector2(440, 594))
	# A beanbag in the left front corner, comics by it.
	var bg := Vector3(-1250, fy, 2550)
	_foot(bg.x - 350, bg.z - 350, bg.x + 350, bg.z + 350)
	blob("fabric", Vector3(360, 280, 340), Transform3D(Basis(Vector3.UP, 0.5), bg + Vector3(0, 250, 0)), Color(0.55, 0.3, 0.65), 12, 8, 0.8, 0.9)
	blob("fabric", Vector3(250, 90, 230), Transform3D(Basis(Vector3.UP, 0.5), bg + Vector3(80, 470, 60)), Color(0.5, 0.27, 0.6), 12, 6)
	for k in 4:
		comic(Vector3(-850 + k * 40, fy + k * 4, 2400 + k * 30), _r.randf_range(-0.6, 0.6), k + 2)
	# A toy chest on the right, its lid propped open, toys poking out; a laundry pile by it.
	var tc := Vector3(1250, fy, 2600)
	_foot(tc.x - 280, tc.z - 400, tc.x + 330, tc.z + 400)
	rbox("wood", Vector3(560, 480, 780), _at(tc + Vector3(0, 240, 0)), Color(0.35, 0.55, 0.75), 12.0, 600.0)
	rbox("wood", Vector3(40, 480, 800), Transform3D(Basis(Vector3.FORWARD, -0.3), tc + Vector3(320, 700, 0)), Color(0.33, 0.52, 0.72), 10.0, 600.0)
	blob("gloss", Vector3(100, 100, 100), _at(tc + Vector3(-60, 500, -180)), Color(0.95, 0.35, 0.3), 12, 8)
	rbox("gloss", Vector3(160, 100, 260), Transform3D(Basis(Vector3.RIGHT, 0.4), tc + Vector3(80, 520, 120)), Color(0.95, 0.8, 0.2), 20.0)
	_dino(tc + Vector3(-120, 440, 140), 0.8, 0.9, Color(0.35, 0.6, 0.8))
	sticker(1, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(tc.x - 281, fy + 300, tc.z - 100)), 40.0)
	sticker(5, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(tc.x - 281, fy + 250, tc.z + 150)), 36.0)
	cloth("fabric", Vector2(520, 460), _at(Vector3(820, fy + 8, 2350), 0.6), Color(0.85, 0.85, 0.8), 70.0, 0.0, 10, 2.0, 10.0)
	cloth("fabric", Vector2(420, 380), _at(Vector3(760, fy + 50, 2330), -0.3), Color(0.25, 0.3, 0.5), 40.0, 0.0, 10, 2.0, 8.0, "jeans")
	cloth("fabric", Vector2(360, 320), _at(Vector3(900, fy + 90, 2400), 1.2), Color(0.95, 0.75, 0.2), 30.0, 0.0, 10, 2.0, 8.0, "tee")


## On the floor: the braided rug, clothes, sneakers, comics, a skateboard, a ball, a wastebasket.
func _floor_things() -> void:
	var fy := floor_y
	# The braided oval rug, with a little thickness.
	var rc := Vector3(-120, fy, 700)
	var rw := 1700.0
	var rd := 1100.0
	var rb := Basis(Vector3.UP, 0.06) * Basis(Vector3.RIGHT, -PI * 0.5)
	_disc("atlas", "rug", Transform3D(rb, rc + Vector3(0, 10, 0)), rw * 0.5, rd * 0.5, Color.WHITE, 40)
	for i in 40:
		var a0 := TAU * i / 40.0
		var a1 := TAU * (i + 1) / 40.0
		var p0 := rc + Basis(Vector3.UP, 0.06) * Vector3(cos(a0) * rw * 0.5, 0, -sin(a0) * rd * 0.5)
		var p1 := rc + Basis(Vector3.UP, 0.06) * Vector3(cos(a1) * rw * 0.5, 0, -sin(a1) * rd * 0.5)
		var on := Vector3(p0.x + p1.x - 2.0 * rc.x, 0, p0.z + p1.z - 2.0 * rc.z).normalized()
		_emit("vc", "", [p0 + Vector3(0, 10, 0), p1 + Vector3(0, 10, 0), p1 + Vector3(0, 1, 0), p0 + Vector3(0, 1, 0)], [on, on, on, on], UV4, Color(0.45, 0.28, 0.2))
	# Clothes: jeans and a t-shirt in heaps, socks.
	cloth("fabric", Vector2(420, 700), _at(Vector3(420, fy + 12, 900), 0.4), Color(0.25, 0.35, 0.6), 22.0, 0.0, 12, 2.0, 10.0, "jeans")
	cloth("fabric", Vector2(520, 460), _at(Vector3(-560, fy + 12, 1000), -0.9), Color(0.95, 0.85, 0.3), 24.0, 0.0, 12, 2.0, 8.0, "tee")
	cloth("fabric", Vector2(140, 280), _at(Vector3(130, fy + 12, 420), 1.2), Color(0.95, 0.95, 0.92), 14.0, 0.0, 6, 1.0, 10.0, "sock")
	cloth("fabric", Vector2(140, 280), _at(Vector3(260, fy + 12, 520), -0.4), Color(0.95, 0.95, 0.92), 14.0, 0.0, 6, 1.0, 10.0, "sock")
	# Sneakers: a sole, an upper, the toe, a stripe; one on its side.
	for k in 2:
		var sp: Vector3 = [Vector3(-80, fy, 1150), Vector3(120, fy, 1250)][k]
		var rot := Basis(Vector3.UP, [0.3, 1.9][k]) * (Basis(Vector3.BACK, 1.35) if k == 1 else Basis())
		var o := sp + (Vector3(0, 55, 0) if k == 1 else Vector3.ZERO)
		rbox("vc", Vector3(110, 30, 290), Transform3D(rot, o + rot * Vector3(0, 15, 0)), Color(0.95, 0.95, 0.93), 10.0)
		blob("vc", Vector3(52, 60, 120), Transform3D(rot, o + rot * Vector3(0, 55, -25)), Color(0.92, 0.25, 0.3), 10, 6, 0.8, 0.8)
		blob("vc", Vector3(50, 36, 70), Transform3D(rot, o + rot * Vector3(0, 40, 80)), Color(0.95, 0.95, 0.93), 10, 5)
		box("vc", Vector3(106, 16, 140), Transform3D(rot * Basis(Vector3.RIGHT, 0.3), o + rot * Vector3(0, 60, -10)), Color(0.2, 0.35, 0.8))
	# Comics fanned on the rug, one open.
	for k in 4:
		comic(Vector3(-40 + k * 60, fy + 12 + k * 3, 780 + k * 25), 0.2 + k * 0.35, k, "comics", k == 3)
	comic(Vector3(-420, fy + 12, 720), -0.5, 1, "magazines")
	# A skateboard (a generic deck with kicktails, trucks and wheels) upside down.
	var sk := Vector3(560, fy, 1500)
	var skb := Basis(Vector3.UP, 1.3)
	var rows := []
	var uvs := []
	for j in 9:
		var row := []
		var urow := []
		var v := j / 8.0
		for i in 3:
			var u := i / 2.0
			var zz := (v - 0.5) * 780.0
			var kick := 40.0 * pow(maxf(0.0, absf(v - 0.5) * 2.0 - 0.7) / 0.3, 2.0)
			var wdt := 200.0 * (1.0 - 0.35 * pow(absf(v - 0.5) * 2.0, 6.0))
			row.append(Vector3((u - 0.5) * wdt, 95 + kick, zz))
			urow.append(Vector2(u, v))
		rows.append(row)
		uvs.append(urow)
	_surf("vc", "", rows, uvs, Transform3D(skb, sk), Color(0.9, 0.3, 0.45), Vector3(0, 1000, 0), false, 12.0)
	for s in [-1.0, 1.0]:
		box("gloss", Vector3(160, 30, 40), Transform3D(skb, sk + skb * Vector3(0, 70, s * 240)), Color(0.7, 0.7, 0.72))
		for w in [-1.0, 1.0]:
			cyl("gloss", 28, 28, 30, Transform3D(skb * Basis(Vector3.FORWARD, PI * 0.5), sk + skb * Vector3(w * 90, 28, s * 240)), Color(0.95, 0.9, 0.5), 12)
	# A ball that rolled against the dresser's corner.
	blob("gloss", Vector3(110, 110, 110), _at(Vector3(560, fy + 110, 330)), Color(0.95, 0.35, 0.3), 16, 10)
	# A wastebasket between the dresser and the bed, paper balls in and round it.
	var wb := Vector3(560, fy, 20)
	cyl("gloss", 110, 140, 300, _at(wb + Vector3(0, 150, 0)), Color(0.85, 0.45, 0.2), 16, false)
	cyl("vc", 108, 108, 2, _at(wb + Vector3(0, 280, 0)), Color(0.2, 0.12, 0.08), 16)
	for p in [Vector3(-30, 300, 10), Vector3(40, 290, -20), Vector3(120, 30, 170), Vector3(-60, 30, 210)]:
		var pv: Vector3 = p
		blob("vc", Vector3(40, 36, 38), Transform3D(Basis(Vector3(0.3, 1, 0.2).normalized(), _r.randf() * 3.0), wb + pv), Color(0.95, 0.94, 0.9), 7, 5)


## On the walls: posters either side of the view, the calendar, the wallpaper border.
func _walls_things() -> void:
	_poster("poster_sunset", Vector3(-850, 560, Z0 + 12), Vector2(400, 540), 0.02)
	_poster("poster_shapes", Vector3(1120, 600, Z0 + 12), Vector2(440, 594), -0.03)
	_print("calendar", Transform3D(Basis(Vector3.BACK, 0.0), Vector3(565, 360, Z0 + 12)), Vector2(180, 240))
	cyl("gloss", 5, 5, 10, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(565, 475, Z0 + 16)), Color(0.7, 0.7, 0.7), 6)


## A poster with a slight curl at a lower corner and tape at its top corners.
func _poster(reg: String, c: Vector3, size: Vector2, rot: float) -> void:
	var b := Basis(Vector3.BACK, rot)
	var rows := []
	var uvs := []
	for j in 5:
		var row := []
		var urow := []
		for i in 5:
			var u := i / 4.0
			var v := j / 4.0
			var curl := 22.0 * pow(maxf(0.0, u - 0.6) / 0.4, 2.0) * pow(maxf(0.0, v - 0.6) / 0.4, 2.0)
			row.append(Vector3((u - 0.5) * size.x, (0.5 - v) * size.y, curl))
			urow.append(Vector2(u, v))
		rows.append(row)
		uvs.append(urow)
	_surf("atlas", reg, rows, uvs, Transform3D(b, c), Color.WHITE, Vector3(0, 0, -1000))
	for s in [-1.0, 1.0]:
		_print("white", Transform3D(b * Basis(Vector3.BACK, s * 0.6), c + b * Vector3(s * (size.x * 0.5 - 6), size.y * 0.5 - 6, 1.2)), Vector2(56, 20), Color(0.95, 0.93, 0.8))


# --- Shell and light --------------------------------------------------------------------------

func _shell() -> void:
	var fy := floor_y
	# Walls: papered, in cells so the baked occlusion can darken the corners, the floor line and the
	# ceiling line; the lower third in a darker tone under a border (a very 80s combination).
	_ao_mode = 2
	var paper := Color(1.0, 0.97, 0.92)
	var lower := Color(0.78, 0.84, 0.9)
	var rail := fy + 900.0
	var walls := [[Vector3(X0, 0, Z0), Vector3(X1, 0, Z0)], [Vector3(X1, 0, Z1), Vector3(X0, 0, Z1)],
			[Vector3(X0, 0, Z1), Vector3(X0, 0, Z0)], [Vector3(X1, 0, Z0), Vector3(X1, 0, Z1)]]
	for w in walls:
		var a: Vector3 = w[0]
		var b: Vector3 = w[1]
		var along := b - a
		# (Facing into the room.)
		var n := along.normalized().cross(Vector3.UP)
		var wl := along.length()
		var nu := int(ceil(wl / 200.0))
		var ys := [fy, fy + 150, fy + 400, rail, rail + 400, fy + 1600, y1 - 350, y1 - 120, y1]
		for i in nu:
			var p0 := a + along * (float(i) / nu)
			var p1 := a + along * (float(i + 1) / nu)
			for j in ys.size() - 1:
				var ya: float = ys[j]
				var yb: float = ys[j + 1]
				var q0 := Vector3(p0.x, ya, p0.z)
				var q1 := Vector3(p1.x, ya, p1.z)
				var q2 := Vector3(p1.x, yb, p1.z)
				var q3 := Vector3(p0.x, yb, p0.z)
				var s0 := wl * float(i) / nu / 520.0
				var s1 := wl * float(i + 1) / nu / 520.0
				_emit("wallpaper", "", [q0, q1, q2, q3], [n, n, n, n], [Vector2(s0, -ya / 520.0), Vector2(s1, -ya / 520.0), Vector2(s1, -yb / 520.0), Vector2(s0, -yb / 520.0)], lower if yb <= rail + 1.0 else paper)
		# The border along the rail, and a picture rail moulding.
		var segs := int(ceil(wl / 470.0))
		for i in segs:
			var p0 := a + along * (float(i) / segs) + n * 1.5
			var p1 := a + along * (float(i + 1) / segs) + n * 1.5
			_quad("atlas", Vector3(p0.x, rail, p0.z), Vector3(p1.x, rail, p1.z), Vector3(p1.x, rail + 68, p1.z), Vector3(p0.x, rail + 68, p0.z), Color(1, 1, 1), UV4, "border")
		rbox("wood", Vector3(wl if absf(along.z) < 1.0 else 18, 22, 18 if absf(along.z) < 1.0 else wl), _at((a + b) * 0.5 + n * 9 + Vector3(0, rail - 6, 0)), Color(0.9, 0.88, 0.82), 4.0, 900.0)
		rbox("wood", Vector3(wl if absf(along.z) < 1.0 else 18, 90, 18 if absf(along.z) < 1.0 else wl), _at((a + b) * 0.5 + n * 9 + Vector3(0, fy + 45, 0)), Color(0.93, 0.91, 0.86), 4.0, 900.0)
	# Ceiling.
	var nx := 6
	var nz := 7
	for i in nx:
		for j in nz:
			var xa := X0 + (X1 - X0) * i / nx
			var xb := X0 + (X1 - X0) * (i + 1) / nx
			var za := Z0 + (Z1 - Z0) * j / nz
			var zb := Z0 + (Z1 - Z0) * (j + 1) / nz
			_quad("vc", Vector3(xa, y1, za), Vector3(xb, y1, za), Vector3(xb, y1, zb), Vector3(xa, y1, zb), Color(0.93, 0.9, 0.85))
	# A ceiling light: a round frosted dome (on) in a brass ring.
	_ao_mode = -1
	blob("glow", Vector3(230, 70, 230), _at(Vector3(0, y1 - 10, 1300)), Color(1.0, 0.93, 0.8), 18, 6)
	_ao_mode = 0
	cyl("gloss", 240, 240, 16, _at(Vector3(0, y1 - 8, 1300)), Color(0.8, 0.66, 0.35), 18, false)
	# The floor: boards running from the back wall to the door, each its own shade, with staggered
	# butt joints and dark seams; in cells (for the occlusion round the walls and under furniture).
	_ao_mode = 1
	var cell := 150.0
	var fx := int(ceil((X1 - X0) / cell))
	var fz := int(ceil((Z1 - Z0) / cell))
	var bw := (X1 - X0) / fx
	var bl := (Z1 - Z0) / fz
	var seam := Color(0.16, 0.1, 0.07)
	for i in fx:
		var xa := X0 + bw * i
		var xb := xa + bw
		var joint := int(_r.randi_range(4, fz - 4))
		var tints := [_jit(Color(0.62, 0.42, 0.27), 0.09), _jit(Color(0.62, 0.42, 0.27), 0.09)]
		var uo := [_r.randf(), _r.randf()]
		for j in fz:
			var za := Z0 + bl * j
			var zb := za + bl
			var part := 0 if j < joint else 1
			var fc: Color = tints[part]
			var u0: float = uo[part]
			_emit("wood", "", [Vector3(xa, fy, za), Vector3(xb, fy, za), Vector3(xb, fy, zb), Vector3(xa, fy, zb)], [Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP],
					[Vector2(u0 + xa / 700.0, za / 2200.0), Vector2(u0 + xb / 700.0, za / 2200.0), Vector2(u0 + xb / 700.0, zb / 2200.0), Vector2(u0 + xa / 700.0, zb / 2200.0)], fc)
		_quad("vc", Vector3(xa - 1.5, fy + 0.4, Z0), Vector3(xa - 1.5, fy + 0.4, Z1), Vector3(xa + 1.5, fy + 0.4, Z1), Vector3(xa + 1.5, fy + 0.4, Z0), seam)
		var jz := Z0 + bl * joint
		_quad("vc", Vector3(xa, fy + 0.4, jz - 1.5), Vector3(xa, fy + 0.4, jz + 1.5), Vector3(xb, fy + 0.4, jz + 1.5), Vector3(xb, fy + 0.4, jz - 1.5), seam)
	_ao_mode = 0


## A lamp for the room's shader (LIT_SHADER): position (room space), colour times energy, range.
var _lamps: Array = []
func _lamp_light(pos: Vector3, col: Color, energy: float, rng: float) -> void:
	_lamps.append([pos, Vector3(col.r, col.g, col.b) * energy * LAMP_GAIN, rng])


## Converts a lamp's energy to the shader's units (matched by eye against the scene lights it
## replaced).
const LAMP_GAIN := 1.0


## Hands the lamps to every lit room material, in world space.
func _apply_lamps() -> void:
	var pos := PackedVector3Array()
	var col := PackedVector3Array()
	var rng := PackedFloat32Array()
	for l in _lamps:
		pos.append(global_transform * (l[0] as Vector3) if is_inside_tree() else l[0])
		col.append(l[1])
		rng.append(l[2])
	for key in _mats:
		var m: ShaderMaterial = _mats[key]
		if key != "glow":
			m.set_shader_parameter("lamp_pos", pos)
			m.set_shader_parameter("lamp_col", col)
			m.set_shader_parameter("lamp_range", rng)


## The room's own lamps (the ceiling light and the window's dusk are in Aquarium._build_light):
## the desk lamp, the bedside lamp by the bed, and the TV's cool glow.
func _lights() -> void:
	var fy := floor_y
	# The desk lamp's bulb (see _desk: the lamp's base at (X0 + 110, top, 820), its shade's joint
	# 330..420 above it, the bulb 90 along the shade's axis).
	var dl := Vector3(X0 + 110, fy + 740.0, 820.0) + Vector3(210, 420, 150) + Vector3(0.5, -1.0, 0.35).normalized() * 90.0
	_lamp_light(dl, Color(1.0, 0.78, 0.5), 2.2, 1900.0)
	_lamp_light(Vector3(790, fy + 1250, Z0 + 140), Color(1.0, 0.72, 0.45), 1.8, 1700.0)
	_lamp_light(Vector3(-600, fy + 800, 350), Color(0.55, 0.7, 1.0), 0.7, 1300.0)
