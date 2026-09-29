class_name TreasureModels
extends RefCounted
## The fourteen Treasure Hunt objects (docs/TREASURE_HUNT.md): ordinary, instantly recognisable,
## wildly out of place in an aquarium. Original and generic (no brands, logos or real designs).
## Each is built from a few hundred to a couple of thousand triangles of simple shapes with vertex
## colour, merged into one mesh per material; built the first time it is needed (never at startup)
## and cached. Modelled standing on y = 0, front toward -Z, about 1 unit across; `node()` scales it
## to its hunt size.

## Its size in the first hunt (metres across its longest side; he is about 1.2 m long). The model is
## scaled to this whatever its own units.
const BASE_SIZE := {
	"duck": 1.1, "fire_hat": 1.2, "skillet": 1.5, "microscope": 1.35, "painting": 1.35, "toy_car": 1.35, "tricycle": 1.35,
	"skis": 1.9, "tv": 1.25, "mower": 1.7, "skateboard": 1.5, "toaster": 1.05, "cone": 1.45, "gnome": 1.4,
}

static var _meshes := {}
static var _mats := {}


## A ready node for `kind` at `scale` of its first-hunt size (the caller places it).
static func node(kind: String, scale := 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Treasure_" + kind
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(kind)
	root.add_child(mi)
	root.scale = Vector3.ONE * size_of(kind, scale) / maxf(0.01, mi.mesh.get_aabb().get_longest_axis_size())
	return root


## Its size across its longest side at `scale` (1 in the first hunt, 0.5 after).
static func size_of(kind: String, scale := 1.0) -> float:
	return float(BASE_SIZE.get(kind, 1.2)) * scale


## Its height when standing at `scale` (for pickup reach and placement).
static func height_of(kind: String, scale := 1.0) -> float:
	var a := mesh(kind).get_aabb()
	return a.size.y * size_of(kind, scale) / maxf(0.01, a.get_longest_axis_size())


static func mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var b := _B.new()
	match kind:
		"duck": _duck(b)
		"fire_hat": _fire_hat(b)
		"skillet": _skillet(b)
		"microscope": _microscope(b)
		"painting": _painting(b)
		"toy_car": _toy_car(b)
		"tricycle": _tricycle(b)
		"skis": _skis(b)
		"tv": _tv(b)
		"mower": _mower(b)
		"skateboard": _skateboard(b)
		"toaster": _toaster(b)
		"cone": _cone(b)
		"gnome": _gnome(b)
	var m := b.commit()
	_meshes[kind] = m
	return m


# --- The objects (each about 1 unit across, standing on y = 0) --------------------------------

static func _duck(b: _B) -> void:
	var yel := Color(1.0, 0.82, 0.12)
	var ora := Color(1.0, 0.45, 0.08)
	b.ellipsoid(Vector3(0, 0.3, 0.05), Vector3(0.42, 0.3, 0.5), yel)            # body
	b.ellipsoid(Vector3(0, 0.46, 0.46), Vector3(0.18, 0.2, 0.16), yel, Basis(Vector3.RIGHT, -0.5))  # tail up
	b.ellipsoid(Vector3(0, 0.72, -0.28), Vector3(0.27, 0.26, 0.26), yel)        # head
	b.ellipsoid(Vector3(0, 0.66, -0.55), Vector3(0.15, 0.06, 0.14), ora)        # bill
	b.ellipsoid(Vector3(0, 0.62, -0.53), Vector3(0.12, 0.04, 0.11), ora.darkened(0.15))
	for sx in [-1.0, 1.0]:
		b.ellipsoid(Vector3(sx * 0.13, 0.79, -0.47), Vector3(0.055, 0.06, 0.04), Color(0.05, 0.05, 0.06))   # eyes
		b.ellipsoid(Vector3(sx * 0.14, 0.81, -0.5), Vector3(0.018, 0.018, 0.012), Color.WHITE)
		b.ellipsoid(Vector3(sx * 0.38, 0.36, 0.08), Vector3(0.08, 0.17, 0.3), yel.darkened(0.06), Basis(Vector3.FORWARD, sx * 0.25))  # wings


static func _fire_hat(b: _B) -> void:
	var red := Color(0.78, 0.08, 0.06)
	var dark := Color(0.45, 0.04, 0.03)
	var gold := Color(0.95, 0.75, 0.25)
	# The long-tailed brim (low at the front, sweeping out behind), the domed crown with its combs,
	# and the upright shield on the front.
	b.ellipsoid(Vector3(0, 0.06, 0.08), Vector3(0.5, 0.05, 0.6), red.darkened(0.1))
	b.ellipsoid(Vector3(0, 0.3, 0.0), Vector3(0.3, 0.3, 0.34), red)
	b.cyl(Vector3(0, 0.1, 0.0), Vector3.UP, 0.3, 0.2, red, 20)
	for k in 4:
		var a := -0.9 + k * 0.6
		b.box(Vector3(0, 0.33, 0.0), Vector3(0.04, 0.3, 0.72), dark, Basis(Vector3.UP, 0.0) * Basis(Vector3.FORWARD, a * 0.7))
	b.box(Vector3(0, 0.52, -0.33), Vector3(0.34, 0.36, 0.04), gold, Basis(Vector3.RIGHT, 0.25))   # shield
	b.box(Vector3(0, 0.52, -0.355), Vector3(0.24, 0.26, 0.02), red, Basis(Vector3.RIGHT, 0.25))
	b.cyl(Vector3(0, 0.53, -0.37), Vector3.FORWARD, 0.07, 0.02, gold, 12)   # a plain emblem (no crest, no numbers)
	b.box(Vector3(0, 0.7, -0.3), Vector3(0.12, 0.08, 0.05), gold, Basis(Vector3.RIGHT, 0.25))   # holder


static func _skillet(b: _B) -> void:
	var iron := Color(0.16, 0.16, 0.17)
	b.cyl(Vector3(0, 0.02, 0.1), Vector3.UP, 0.38, 0.04, iron, 28, "shiny")
	b.tube(Vector3(0, 0.04, 0.1), 0.38, 0.4, 0.14, iron.lightened(0.05), 28, "shiny")     # the side wall
	b.cyl(Vector3(0, 0.045, 0.1), Vector3.UP, 0.345, 0.012, Color(0.1, 0.1, 0.11), 28, "shiny")
	b.box(Vector3(0, 0.1, -0.52), Vector3(0.09, 0.05, 0.6), Color(0.28, 0.16, 0.08), Basis(Vector3.RIGHT, -0.12))   # handle
	b.box(Vector3(0, 0.1, -0.25), Vector3(0.1, 0.06, 0.12), iron, Basis(), "shiny")
	b.cyl(Vector3(0, 0.14, -0.79), Vector3.UP, 0.03, 0.08, Color(0.1, 0.1, 0.1), 10)     # hanging hole ring


static func _microscope(b: _B) -> void:
	var body := Color(0.92, 0.92, 0.94)
	var black := Color(0.08, 0.08, 0.09)
	var chrome := Color(0.75, 0.77, 0.8)
	b.box(Vector3(0, 0.05, 0.05), Vector3(0.5, 0.1, 0.6), body)                            # base
	b.box(Vector3(0, 0.42, 0.25), Vector3(0.14, 0.7, 0.16), body, Basis(Vector3.RIGHT, -0.2))   # arm
	b.box(Vector3(0, 0.36, -0.08), Vector3(0.42, 0.04, 0.34), black)                        # stage
	b.box(Vector3(0, 0.39, -0.08), Vector3(0.3, 0.012, 0.1), Color(0.7, 0.85, 0.95))        # the slide
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.12, 0.385, -0.02), Vector3(0.04, 0.01, 0.18), chrome, Basis(), "shiny")   # clips
	b.cyl(Vector3(0, 0.62, -0.02), Vector3(0, 1, -0.45).normalized(), 0.075, 0.46, body, 16)   # tube
	b.cyl(Vector3(0, 0.9, 0.1), Vector3(0, 1, -0.45).normalized(), 0.05, 0.16, black, 14)       # eyepiece
	b.cyl(Vector3(0, 0.46, -0.1), Vector3.UP, 0.1, 0.05, chrome, 16, "shiny")               # turret
	for k in 3:
		var a := k * TAU / 3.0
		b.cyl(Vector3(sin(a) * 0.06, 0.41, -0.1 + cos(a) * 0.06), Vector3.UP, 0.025, 0.09, chrome, 10, "shiny")   # objectives
	for sx in [-1.0, 1.0]:
		b.cyl(Vector3(sx * 0.1, 0.28, 0.25), Vector3.RIGHT, 0.06, 0.05, black, 14)           # focus knobs
	b.cyl(Vector3(0, 0.2, -0.08), Vector3.UP, 0.06, 0.04, Color(1.0, 0.95, 0.7), 12, "glow")   # the light


static func _painting(b: _B) -> void:
	var gilt := Color(0.8, 0.6, 0.22)
	# A framed picture propped up, leaning back on a little stand.
	var lean := Basis(Vector3.RIGHT, 0.2)
	var c := Vector3(0, 0.42, 0.0)
	for p in [[Vector3(0, 0.36, 0), Vector3(1.0, 0.08, 0.08)], [Vector3(0, -0.36, 0), Vector3(1.0, 0.08, 0.08)],
			[Vector3(-0.46, 0, 0), Vector3(0.08, 0.8, 0.08)], [Vector3(0.46, 0, 0), Vector3(0.08, 0.8, 0.08)]]:
		b.box(c + lean * (p[0] as Vector3), p[1], gilt, lean, "shiny")
	b.box(c + lean * Vector3(0, 0, 0.03), Vector3(0.86, 0.66, 0.02), Color(0.35, 0.25, 0.15), lean)   # backing
	b.quad_tex(c + lean * Vector3(0, 0, -0.012), lean, Vector2(0.86, 0.66))
	b.box(Vector3(0, 0.3, 0.26), Vector3(0.05, 0.62, 0.05), Color(0.35, 0.22, 0.12), Basis(Vector3.RIGHT, -0.45))   # the stand leg


static func _toy_car(b: _B) -> void:
	var red := Color(0.1, 0.45, 0.9)
	var glass := Color(0.6, 0.85, 0.95)
	b.box(Vector3(0, 0.26, 0), Vector3(0.52, 0.2, 1.0), red, Basis(), "shiny")        # body
	b.box(Vector3(0, 0.44, 0.08), Vector3(0.46, 0.2, 0.52), red.lightened(0.05), Basis(), "shiny")   # cabin
	b.box(Vector3(0, 0.45, -0.19), Vector3(0.42, 0.16, 0.02), glass, Basis(Vector3.RIGHT, -0.5), "shiny")   # windscreen
	b.box(Vector3(0, 0.45, 0.34), Vector3(0.42, 0.14, 0.02), glass, Basis(Vector3.RIGHT, 0.4), "shiny")
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.235, 0.45, 0.08), Vector3(0.02, 0.13, 0.4), glass, Basis(), "shiny")   # side windows
		for sz in [-0.32, 0.32]:
			b.cyl(Vector3(sx * 0.27, 0.15, sz), Vector3.RIGHT, 0.15, 0.1, Color(0.08, 0.08, 0.08), 18)   # wheels
			b.cyl(Vector3(sx * 0.325, 0.15, sz), Vector3.RIGHT, 0.07, 0.02, Color(0.8, 0.8, 0.82), 12, "shiny")
		b.ellipsoid(Vector3(sx * 0.17, 0.28, -0.5), Vector3(0.06, 0.05, 0.02), Color(1.0, 0.95, 0.7), Basis(), "glow")   # lamps
	b.box(Vector3(0, 0.2, -0.51), Vector3(0.4, 0.06, 0.03), Color(0.8, 0.8, 0.82), Basis(), "shiny")   # bumper


static func _tricycle(b: _B) -> void:
	var frame := Color(0.85, 0.12, 0.12)
	var tyre := Color(0.08, 0.08, 0.08)
	var chrome := Color(0.8, 0.8, 0.84)
	b.torus(Vector3(0, 0.3, -0.35), Vector3.RIGHT, 0.27, 0.035, tyre, 22, 8)            # big front wheel
	b.cyl(Vector3(0, 0.3, -0.35), Vector3.RIGHT, 0.05, 0.1, chrome, 10, "shiny")
	for k in 6:
		var a := k * PI / 6.0
		b.box(Vector3(0, 0.3, -0.35), Vector3(0.012, 0.5, 0.012), chrome, Basis(Vector3.RIGHT, a), "shiny")   # spokes
	for sx in [-1.0, 1.0]:
		b.torus(Vector3(sx * 0.3, 0.16, 0.35), Vector3.RIGHT, 0.14, 0.03, tyre, 18, 8)       # rear wheels
		b.cyl(Vector3(sx * 0.3, 0.16, 0.35), Vector3.RIGHT, 0.04, 0.06, chrome, 10, "shiny")
		b.cyl(Vector3(sx * 0.12, 0.3, -0.35), Vector3.RIGHT, 0.018, 0.1, chrome, 8, "shiny")  # pedal cranks
		b.box(Vector3(sx * 0.2, 0.27, -0.35), Vector3(0.08, 0.02, 0.05), tyre)                  # pedals
	b.cyl(Vector3(0, 0.16, 0.35), Vector3.RIGHT, 0.025, 0.6, frame, 10)                      # rear axle
	b.cyl(Vector3(0, 0.33, 0.0), Vector3(0, 0.35, 1.0).normalized(), 0.035, 0.75, frame, 10)   # backbone
	b.cyl(Vector3(0, 0.52, -0.33), Vector3(0, 1, 0.12).normalized(), 0.03, 0.45, frame, 10)    # fork / head tube
	b.cyl(Vector3(0, 0.76, -0.3), Vector3.RIGHT, 0.022, 0.46, chrome, 10, "shiny")            # handlebar
	for sx in [-1.0, 1.0]:
		b.cyl(Vector3(sx * 0.24, 0.76, -0.3), Vector3.RIGHT, 0.035, 0.1, Color(0.1, 0.4, 0.9), 10)   # grips
	b.ellipsoid(Vector3(0, 0.5, 0.2), Vector3(0.14, 0.04, 0.18), Color(0.1, 0.1, 0.12))          # seat
	b.box(Vector3(0, 0.25, 0.35), Vector3(0.5, 0.03, 0.16), frame)                              # rear step


static func _skis(b: _B) -> void:
	var cols := [Color(0.95, 0.35, 0.1), Color(0.2, 0.7, 0.95)]
	# Stood up crossed in an X, the way skis are propped, with the poles leaning beside them: flat
	# on the ground they were only a sliver.
	for k in 2:
		var sx := -1.0 if k == 0 else 1.0
		var col: Color = cols[k]
		var tilt := Basis(Vector3.FORWARD, sx * 0.3) * Basis(Vector3.RIGHT, -0.12)
		var c := Vector3(-sx * 0.12, 0.0, 0.05 * sx)
		var up := tilt.y
		b.box(c + up * 0.8, Vector3(0.14, 1.6, 0.04), col, tilt, "shiny")
		b.box(c + up * 1.62 + tilt.z * -0.05, Vector3(0.14, 0.14, 0.04), col, tilt * Basis(Vector3.RIGHT, 0.6), "shiny")   # curled tip
		b.box(c + up * 0.62 + tilt.z * -0.04, Vector3(0.13, 0.26, 0.06), Color(0.15, 0.15, 0.17), tilt)       # binding
		b.box(c + up * 0.66 + tilt.z * -0.09, Vector3(0.09, 0.08, 0.1), Color(0.3, 0.3, 0.33), tilt, "shiny")
		b.box(c + up * 1.1 + tilt.z * -0.022, Vector3(0.045, 0.6, 0.006), col.lightened(0.45), tilt)       # stripe
	for k in 2:
		var sx := -1.0 if k == 0 else 1.0
		var tilt := Basis(Vector3.FORWARD, sx * 0.18) * Basis(Vector3.RIGHT, 0.22)
		var base := Vector3(sx * 0.42, 0.0, 0.12)
		b.cyl(base + tilt.y * 0.62, tilt.y, 0.018, 1.2, Color(0.8, 0.8, 0.84), 8, "shiny")
		b.cyl(base + tilt.y * 1.16, tilt.y, 0.034, 0.16, Color(0.1, 0.1, 0.1), 10)          # grip
		b.torus(base + tilt.y * 0.12, tilt.y, 0.07, 0.012, Color(0.1, 0.1, 0.1), 12, 6)      # basket


static func _tv(b: _B) -> void:
	var wood := Color(0.42, 0.26, 0.13)
	var grey := Color(0.72, 0.7, 0.66)
	b.box(Vector3(0, 0.42, 0.05), Vector3(0.95, 0.7, 0.62), wood)                       # cabinet
	b.box(Vector3(0, 0.44, 0.38), Vector3(0.7, 0.5, 0.2), wood.darkened(0.2))          # the tube's back
	b.box(Vector3(-0.12, 0.43, -0.27), Vector3(0.64, 0.56, 0.02), grey)                  # bezel
	b.ellipsoid(Vector3(-0.12, 0.43, -0.28), Vector3(0.28, 0.24, 0.03), Color(0.18, 0.28, 0.3), Basis(), "glow")   # screen
	b.box(Vector3(0.33, 0.43, -0.27), Vector3(0.2, 0.56, 0.02), grey.darkened(0.1))     # control panel
	for k in 2:
		b.cyl(Vector3(0.33, 0.58 - k * 0.14, -0.29), Vector3.FORWARD, 0.045, 0.04, Color(0.12, 0.12, 0.12), 14)   # dials
	for k in 4:
		b.box(Vector3(0.33, 0.33 - k * 0.035, -0.285), Vector3(0.13, 0.012, 0.01), Color(0.2, 0.2, 0.2))     # speaker grille
	for sx in [-1.0, 1.0]:
		b.cyl(Vector3(sx * 0.4, 0.04, 0.05), Vector3.UP, 0.035, 0.08, Color(0.2, 0.15, 0.1), 8)
		b.cyl(Vector3(sx * 0.12, 0.95, 0.15), Vector3(sx * 0.5, 1, 0).normalized(), 0.012, 0.5, Color(0.8, 0.8, 0.84), 6, "shiny")   # rabbit ears
	b.ellipsoid(Vector3(0, 0.79, 0.15), Vector3(0.07, 0.03, 0.05), Color(0.15, 0.15, 0.15))


static func _mower(b: _B) -> void:
	var green := Color(0.15, 0.55, 0.2)
	var black := Color(0.08, 0.08, 0.09)
	b.box(Vector3(0, 0.17, 0.1), Vector3(0.6, 0.12, 0.62), green, Basis(), "shiny")            # deck
	b.ellipsoid(Vector3(0, 0.26, 0.08), Vector3(0.26, 0.1, 0.26), green.darkened(0.1), Basis(), "shiny")
	b.cyl(Vector3(0.0, 0.36, 0.05), Vector3.UP, 0.12, 0.14, black, 14)                          # engine
	b.cyl(Vector3(0.0, 0.46, 0.05), Vector3.UP, 0.09, 0.05, Color(0.8, 0.1, 0.1), 14)           # cap
	b.box(Vector3(0.1, 0.4, -0.08), Vector3(0.06, 0.06, 0.06), Color(0.9, 0.8, 0.2))            # fuel cap
	for sx in [-1.0, 1.0]:
		for sz in [-0.14, 0.36]:
			b.cyl(Vector3(sx * 0.32, 0.1, sz), Vector3.RIGHT, 0.1, 0.06, black, 16)             # wheels
			b.cyl(Vector3(sx * 0.35, 0.1, sz), Vector3.RIGHT, 0.04, 0.01, Color(0.8, 0.8, 0.8), 10)
		b.cyl(Vector3(sx * 0.22, 0.5, 0.6), Vector3(0, 0.75, 0.6).normalized(), 0.022, 0.85, Color(0.8, 0.8, 0.84), 8, "shiny")   # handle
	b.cyl(Vector3(0, 0.83, 0.87), Vector3.RIGHT, 0.025, 0.5, black, 10)                          # grip bar
	b.box(Vector3(0, 0.3, 0.55), Vector3(0.44, 0.24, 0.24), Color(0.3, 0.3, 0.32))              # grass bag
	b.box(Vector3(0, 0.78, 0.8), Vector3(0.36, 0.02, 0.04), Color(0.8, 0.1, 0.1), Basis(Vector3.RIGHT, 0.5))   # safety bar


static func _skateboard(b: _B) -> void:
	var deck := Color(0.3, 0.2, 0.55)
	# The deck with kicked-up nose and tail, grip tape, trucks and four wheels.
	b.box(Vector3(0, 0.16, 0), Vector3(0.36, 0.035, 1.0), deck)
	b.box(Vector3(0, 0.178, 0), Vector3(0.34, 0.006, 0.98), Color(0.1, 0.1, 0.1))
	for sz in [-1.0, 1.0]:
		b.box(Vector3(0, 0.2, sz * 0.58), Vector3(0.36, 0.035, 0.2), deck, Basis(Vector3.RIGHT, -sz * 0.35))
		b.box(Vector3(0, 0.122, sz * 0.33), Vector3(0.24, 0.035, 0.08), Color(0.78, 0.78, 0.8), Basis(), "shiny")   # truck
		b.cyl(Vector3(0, 0.07, sz * 0.33), Vector3.RIGHT, 0.02, 0.4, Color(0.7, 0.7, 0.72), 8, "shiny")        # axle
		for sx in [-1.0, 1.0]:
			b.cyl(Vector3(sx * 0.17, 0.07, sz * 0.33), Vector3.RIGHT, 0.065, 0.06, Color(1.0, 0.85, 0.3), 14)   # wheels
	b.box(Vector3(0, 0.1405, 0.0), Vector3(0.2, 0.004, 0.5), Color(0.95, 0.55, 0.15))   # a plain stripe underneath


static func _toaster(b: _B) -> void:
	var steel := Color(0.82, 0.83, 0.86)
	b.box(Vector3(0, 0.3, 0), Vector3(0.62, 0.5, 0.36), steel, Basis(), "shiny")
	b.ellipsoid(Vector3(0, 0.55, 0), Vector3(0.31, 0.06, 0.18), steel, Basis(), "shiny")        # rounded top
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.12, 0.6, 0), Vector3(0.08, 0.02, 0.26), Color(0.05, 0.05, 0.05))    # slots
		b.box(Vector3(sx * 0.12, 0.62, 0), Vector3(0.07, 0.07, 0.22), Color(0.85, 0.6, 0.3))     # toast peeking out
	b.box(Vector3(0.33, 0.42, 0.0), Vector3(0.04, 0.08, 0.04), Color(0.1, 0.1, 0.1))              # lever
	b.box(Vector3(0.33, 0.25, 0.0), Vector3(0.012, 0.3, 0.03), Color(0.3, 0.3, 0.3))              # its slot
	b.cyl(Vector3(0.315, 0.16, 0.1), Vector3.RIGHT, 0.035, 0.03, Color(0.1, 0.1, 0.1), 12)       # dial
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.cyl(Vector3(sx * 0.25, 0.02, sz * 0.13), Vector3.UP, 0.03, 0.04, Color(0.1, 0.1, 0.1), 8)   # feet


static func _cone(b: _B) -> void:
	var ora := Color(1.0, 0.42, 0.05)
	b.box(Vector3(0, 0.03, 0), Vector3(0.62, 0.06, 0.62), ora.darkened(0.15))                     # base
	b.cone(Vector3(0, 0.06, 0), 0.24, 0.035, 0.94, ora, 24)
	b.cone(Vector3(0, 0.36, 0), 0.185, 0.157, 0.13, Color(0.97, 0.97, 0.97), 24)                 # reflective bands (proud of the cone)
	b.cone(Vector3(0, 0.62, 0), 0.127, 0.103, 0.1, Color(0.97, 0.97, 0.97), 24)


static func _gnome(b: _B) -> void:
	var red := Color(0.85, 0.1, 0.1)
	var blue := Color(0.15, 0.3, 0.75)
	var skin := Color(1.0, 0.78, 0.65)
	b.ellipsoid(Vector3(0, 0.08, -0.02), Vector3(0.17, 0.08, 0.2), Color(0.3, 0.18, 0.1))       # boots
	b.ellipsoid(Vector3(0, 0.3, 0), Vector3(0.22, 0.25, 0.2), blue)                             # coat / body
	b.box(Vector3(0, 0.3, -0.02), Vector3(0.44, 0.05, 0.4), Color(0.25, 0.15, 0.08))           # belt
	b.box(Vector3(0, 0.3, -0.21), Vector3(0.07, 0.07, 0.02), Color(0.95, 0.8, 0.3), Basis(), "shiny")
	b.ellipsoid(Vector3(0, 0.58, -0.01), Vector3(0.16, 0.15, 0.15), skin)                       # face
	b.ellipsoid(Vector3(0, 0.58, -0.16), Vector3(0.04, 0.04, 0.04), skin.darkened(0.08))        # nose
	b.ellipsoid(Vector3(0, 0.46, -0.1), Vector3(0.16, 0.16, 0.08), Color(0.97, 0.97, 0.97))    # beard
	b.cone(Vector3(0, 0.44, -0.12), 0.12, 0.01, 0.2, Color(0.97, 0.97, 0.97), 12, Basis(Vector3.RIGHT, PI * 0.9))
	for sx in [-1.0, 1.0]:
		b.ellipsoid(Vector3(sx * 0.06, 0.62, -0.13), Vector3(0.02, 0.022, 0.015), Color(0.05, 0.05, 0.05))   # eyes
		b.ellipsoid(Vector3(sx * 0.2, 0.34, -0.04), Vector3(0.06, 0.12, 0.06), blue.darkened(0.1), Basis(Vector3.FORWARD, sx * 0.4))   # arms
		b.ellipsoid(Vector3(sx * 0.22, 0.24, -0.1), Vector3(0.045, 0.045, 0.045), skin)   # hands
	b.cone(Vector3(0, 0.66, 0.0), 0.17, 0.0, 0.62, red, 16, Basis(Vector3.RIGHT, 0.18))        # the pointed hat


# --- A little mesh builder ---------------------------------------------------------------------

## Shapes with vertex colour into one surface per material ("matte", "shiny", "glow", "tex").
class _B:
	var _st := {}
	## The shape being built's centre: each triangle is turned to face away from it (so lighting is
	## right whatever order its corners were given in). `_inward` flips that (a tube's inner wall).
	var _hint := Vector3.ZERO
	var _inward := false

	func _s(mat: String) -> SurfaceTool:
		if not _st.has(mat):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_st[mat] = st
		return _st[mat]

	func tri(mat: String, a: Vector3, b: Vector3, c: Vector3, col: Color, uv := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]) -> void:
		var st := _s(mat)
		var n := (c - a).cross(b - a).normalized()
		var out := ((a + b + c) / 3.0 - _hint) * (-1.0 if _inward else 1.0)
		if n.dot(out) < 0.0:
			var t := b
			b = c
			c = t
			var tu = uv[1]
			uv = [uv[0], uv[2], tu]
			n = -n
		# (Godot's front faces wind clockwise.)
		for v in [[a, uv[0]], [b, uv[1]], [c, uv[2]]]:
			st.set_normal(n)
			st.set_color(col)
			st.set_uv(v[1])
			st.add_vertex(v[0])

	func quad(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
		tri(mat, a, b, c, col)
		tri(mat, a, c, d, col)

	func box(c: Vector3, size: Vector3, col: Color, basis := Basis(), mat := "matte") -> void:
		_hint = c
		_inward = false
		var h := size * 0.5
		var corners := []
		for i in 8:
			var p := Vector3(h.x * (1 if i & 1 else -1), h.y * (1 if i & 2 else -1), h.z * (1 if i & 4 else -1))
			corners.append(c + basis * p)
		for f in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
			quad(mat, corners[f[0]], corners[f[1]], corners[f[2]], corners[f[3]], col)

	## A cylinder centred at `c` along `axis`.
	func cyl(c: Vector3, axis: Vector3, r: float, h: float, col: Color, sides := 16, mat := "matte") -> void:
		cone(c - axis.normalized() * h * 0.5, r, r, h, col, sides, _basis_up(axis), mat)

	## A truncated cone from its base centre `c` upward (along basis.y): radii r0 (base) and r1.
	func cone(c: Vector3, r0: float, r1: float, h: float, col: Color, sides := 16, basis := Basis(), mat := "matte") -> void:
		var up := basis.y
		_hint = c + up * h * 0.5
		_inward = false
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var d0 := basis * Vector3(cos(a0), 0, sin(a0))
			var d1 := basis * Vector3(cos(a1), 0, sin(a1))
			var b0 := c + d0 * r0
			var b1 := c + d1 * r0
			var t0 := c + up * h + d0 * r1
			var t1 := c + up * h + d1 * r1
			quad(mat, b0, t0, t1, b1, col)
			tri(mat, c, b0, b1, col.darkened(0.1))
			if r1 > 0.001:
				tri(mat, c + up * h, t1, t0, col.lightened(0.04))

	## A ring wall (a tube) standing on `c`: inner and outer radius, height.
	func tube(c: Vector3, r_in: float, r_out: float, h: float, col: Color, sides := 24, mat := "matte") -> void:
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			_hint = c + Vector3.UP * h * 0.5
			_inward = false
			quad(mat, c + d0 * r_out, c + d0 * r_out + Vector3.UP * h, c + d1 * r_out + Vector3.UP * h, c + d1 * r_out, col)
			_inward = true
			quad(mat, c + d1 * r_in, c + d1 * r_in + Vector3.UP * h, c + d0 * r_in + Vector3.UP * h, c + d0 * r_in, col.darkened(0.2))
			_inward = false
			_hint = c + d0 * (r_in + r_out) * 0.5
			quad(mat, c + d0 * r_in + Vector3.UP * h, c + d0 * r_out + Vector3.UP * h, c + d1 * r_out + Vector3.UP * h, c + d1 * r_in + Vector3.UP * h, col.lightened(0.05))
		_inward = false

	func ellipsoid(c: Vector3, radii: Vector3, col: Color, basis := Basis(), mat := "matte", rings := 8, segs := 14) -> void:
		_hint = c
		_inward = false
		var pts := []
		for j in rings + 1:
			var v := PI * j / rings
			var row := []
			for i in segs + 1:
				var u := TAU * i / segs
				row.append(c + basis * Vector3(sin(v) * cos(u) * radii.x, cos(v) * radii.y, sin(v) * sin(u) * radii.z))
			pts.append(row)
		for j in rings:
			for i in segs:
				quad(mat, pts[j][i], pts[j][i + 1], pts[j + 1][i + 1], pts[j + 1][i], col)

	func torus(c: Vector3, axis: Vector3, big: float, small: float, col: Color, segs := 20, sides := 8, mat := "matte") -> void:
		var bas := _basis_up(axis)
		for i in segs:
			for j in sides:
				var p := []
				for di in [0, 1]:
					for dj in [0, 1]:
						var u: float = TAU * (i + di) / segs
						var v: float = TAU * (j + dj) / sides
						var ring := Vector3(cos(u), 0, sin(u))
						p.append(c + bas * (ring * (big + small * cos(v)) + Vector3.UP * small * sin(v)))
				var um := TAU * (i + 0.5) / segs
				_hint = c + bas * (Vector3(cos(um), 0, sin(um)) * big)
				_inward = false
				quad(mat, p[0], p[2], p[3], p[1], col)

	## The painting's picture: a textured quad facing -Z in `basis`.
	func quad_tex(c: Vector3, basis: Basis, size: Vector2) -> void:
		var hx := basis.x * size.x * 0.5
		var hy := basis.y * size.y * 0.5
		var a := c - hx - hy
		var b := c + hx - hy
		var d := c + hx + hy
		var e := c - hx + hy
		# (Facing out of the front, -Z.)
		_hint = c + basis.z
		_inward = false
		tri("tex", a, e, d, Color.WHITE, [Vector2(0, 1), Vector2(0, 0), Vector2(1, 0)])
		tri("tex", a, d, b, Color.WHITE, [Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)])

	func _basis_up(axis: Vector3) -> Basis:
		var y := axis.normalized()
		var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		return Basis(x, y, x.cross(y).normalized() * -1.0)

	func commit() -> ArrayMesh:
		var m := ArrayMesh.new()
		for key in ["matte", "shiny", "glow", "tex"]:
			if not _st.has(key):
				continue
			var st: SurfaceTool = _st[key]
			st.commit(m)
			m.surface_set_material(m.get_surface_count() - 1, TreasureModels.material(key))
		return m


static func material(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.62
	match key:
		"shiny":
			m.roughness = 0.28
			m.metallic = 0.35
		"glow":
			m.emission_enabled = true
			m.emission = Color(0.6, 0.7, 0.7)
			m.emission_energy_multiplier = 0.5
			m.roughness = 0.2
		"tex":
			m.vertex_color_use_as_albedo = false
			m.albedo_texture = _picture()
			m.roughness = 0.75
	# (A faint rim so a treasure reads against moss of a similar colour, up close; no glow beacon.)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6
	_mats[key] = m
	return m


## An original little landscape for the painting: sky, sun, hills, a tree, a lake.
static func _picture() -> Texture2D:
	var w := 96
	var h := 72
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var fy := float(y) / h
			var fx := float(x) / w
			var c := Color(0.45, 0.7, 0.95).lerp(Color(0.95, 0.85, 0.7), fy * 1.1)
			if Vector2(fx - 0.76, fy - 0.26).length() < 0.09:
				c = Color(1.0, 0.85, 0.3)
			var hill1 := 0.55 + 0.08 * sin(fx * 7.0 + 1.0)
			var hill2 := 0.66 + 0.05 * sin(fx * 11.0 + 3.0)
			if fy > hill1:
				c = Color(0.35, 0.6, 0.3)
			if fy > hill2:
				c = Color(0.25, 0.5, 0.22)
			if fy > 0.8 and absf(fx - 0.35) < 0.22 - (fy - 0.8) * 0.5:
				c = Color(0.3, 0.55, 0.8)
			if absf(fx - 0.2) < 0.012 and fy > 0.45 and fy < 0.66:
				c = Color(0.35, 0.22, 0.12)
			if Vector2((fx - 0.2) * 1.3, fy - 0.45).length() < 0.08:
				c = Color(0.15, 0.45, 0.2)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
