class_name Ecosystem
extends Node
## Expansion 5's living world (docs/ECOSYSTEM.md): places each ball's creatures in their habitats,
## ticks only the ones near the axolotl on his current ball (everything else costs nothing),
## notices when he discovers a species, and gathers the creatures' vegetation wake points.

## Species id -> the name shown when it is discovered. Order is the completion catalog's order.
const SPECIES := {
	"shrimp": "Shrimp shoal",
	"snail": "Canopy snail",
	"hopper": "Leaf hopper",
	"glowworm": "Cave glow-worms",
	"stalker": "Reed stalker",
	"crab": "Crab guardian",
	"eel": "Cave eel",
	"puffer": "Pufferfish",
}
## How often activation and discovery are re-checked (they need not be exact per frame).
const CHECK_DT := 0.25

var balls: Array = []
var active: Array = []
var _check_t := 0.0


func populate(p_balls: Array) -> void:
	balls = p_balls
	for b in balls:
		_populate_ball(b)


func all_critters() -> Array:
	var out := []
	for b in balls:
		out.append_array(b.critters)
	return out


# --- Placement ------------------------------------------------------------------------------

func _seed(b: MossBall, sp: String, i: int) -> int:
	return hash([b.index, sp, i])


static func _ll(v: Vector2) -> Vector3:
	return MossBall.dir_ll(v.x, v.y)


func _populate_ball(b: MossBall) -> void:
	var lb: LevelBuilder = b.get_meta("builder")
	var routes := {}
	var caves := []
	for h in lb.bot_hints:
		if h.has("route"):
			routes[str(h["route"])] = h
		if h.has("cave"):
			caves.append(h)
	var R := func(dlat: float, dlon: float) -> Vector3:
		return _ll(WorldExpansion._rel(b.index, Levels.LINKS[b.index - 1][0] if b.index >= 3 else 0, dlat, dlon))
	# Cave life: glow-worms in every grotto.
	for i in caves.size():
		var h: Dictionary = caves[i]
		var gw := GlowWorms.new()
		gw.place(b, h["centre"], float(h.get("radius", 8.0)), _seed(b, "glowworm", i))
	match b.index:
		0:
			_shoal(b, MossBall.dir_ll(24, 4), 5.0, 0)
			_shoal(b, MossBall.dir_ll(34, -8), 5.0, 1)
			_stalker(b, MossBall.dir_ll(-58, 32), 11.0, 0)
		1:
			_shoal(b, MossBall.dir_ll(0, -80), 5.0, 0)
			_puffer(b, MossBall.dir_ll(4, 60), 6.0, 1.5, 0)
			_puffer(b, MossBall.dir_ll(64, 66), 6.0, 1.5, 1)
			if caves.size() > 0:
				_eel(b, caves[0], 0)
		2:
			# (Well away from the parasites' zones: a stalker should not harass a required fight.)
			_stalker(b, MossBall.dir_ll(-55, 95), 10.0, 0)
			var hc := {}
			for h in lb.bot_hints:
				if h.has("canopy"):
					hc = h
			if not hc.is_empty():
				var sp: Array = hc["spiral"]
				var k := 0
				for si in [3, 7, 11]:
					_snail(b, Levels.leaf_mid(sp[si], 1.0, 0.0).origin, Levels.leaf_mid(sp[si], 2.4, 0.0).origin, k)
					k += 1
				_snail(b, Levels.leaf_mid(hc["c3"], 1.2, 0.0).origin, Levels.leaf_mid(hc["c3"], 3.8, 0.0).origin, k)
			if routes.has("canopy"):
				_hopper(b, (routes["canopy"]["tops"] as Array).slice(0, 16), 1, 0)
			var j := 0
			for n in [3, 13, 23, 33, 43, 53]:
				var name_ := "jungle stem %d" % n
				if routes.has(name_):
					var tops: Array = routes[name_]["tops"]
					var top: Vector3 = tops[tops.size() / 2]
					var tan := MossBall.frame_at(b.up_at(top), float(n * 37 % 360)).z
					_snail(b, top, top + tan * 0.35, 4 + j)
					j += 1
			var hk := 1
			for n in [8, 28, 48]:
				var name_ := "jungle stem %d" % n
				if routes.has(name_):
					_hopper(b, routes[name_]["tops"], 1, hk)
					hk += 1
		3:
			_shoal(b, R.call(8, 10), 6.0, 0)
			_shoal(b, R.call(14, 24), 4.0, 1)
			_puffer(b, R.call(46, -20), 6.0, 1.4, 0)
			if routes.has("arch"):
				var at: Array = routes["arch"]["tops"]
				_snail(b, at[at.size() - 1], at[at.size() - 2], 0)
			if routes.has("terraces"):
				_hopper(b, routes["terraces"]["tops"], 0, 0)
			for h in caves:
				_crab(b, h, 0)
		4:
			_stalker(b, R.call(0, 40), 8.0, 0)
			_stalker(b, R.call(0, 78), 8.0, 1)
			_puffer(b, R.call(24, 60), 5.0, 3.2, 0)
			for h in caves:
				_crab(b, h, 0)
				_eel(b, h, 0)
		5:
			_shoal(b, R.call(6, -6), 6.0, 0)
			if routes.has("spire"):
				var st: Array = routes["spire"]["tops"]
				var k := 0
				for si in [2, 7, 11]:
					if si + 1 < st.size():
						_snail(b, st[si], (st[si] as Vector3).lerp(st[si + 1], 0.25), k)
						k += 1
				_hopper(b, st, 1, 0)
			if routes.has("shelves"):
				var sh: Array = routes["shelves"]["tops"]
				_snail(b, sh[1], (sh[1] as Vector3).lerp(sh[0], 0.2), 3)
				_snail(b, sh[2], (sh[2] as Vector3).lerp(sh[1], 0.2), 4)
		6:
			_shoal(b, R.call(10, 40), 4.0, 0)
			_puffer(b, R.call(8, 42), 5.0, 1.6, 0)
			if routes.has("high shelf"):
				var hs: Array = routes["high shelf"]["tops"]
				_snail(b, hs[hs.size() - 1], hs[hs.size() - 2], 0)
			for i in caves.size():
				if i == 0:
					_crab(b, caves[i], 0)
				_eel(b, caves[i], i)


func _shoal(b: MossBall, d: Vector3, deg: float, i: int) -> void:
	ShrimpShoal.new().place(b, d, deg, _seed(b, "shrimp", i))


func _stalker(b: MossBall, d: Vector3, deg: float, i: int) -> void:
	ReedStalker.new().place(b, d, deg, _seed(b, "stalker", i))


func _puffer(b: MossBall, d: Vector3, deg: float, hover: float, i: int) -> void:
	Pufferfish.new().place(b, d, deg, hover, _seed(b, "puffer", i))


func _snail(b: MossBall, p0: Vector3, p1: Vector3, i: int) -> void:
	CanopySnail.new().place(b, p0, p1, _seed(b, "snail", i))


func _hopper(b: MossBall, steps: Array, start: int, i: int) -> void:
	if steps.size() >= 3:
		LeafHopper.new().place(b, steps, start, _seed(b, "hopper", i))


## A crab guards a grotto's mouth: beside the approach, facing out.
func _crab(b: MossBall, h: Dictionary, i: int) -> void:
	var door: Vector3 = h["door"]
	var entry: Vector3 = h["entry"]
	var up := b.up_at(entry)
	var out := entry - door
	out -= up * out.dot(up)
	var side := out.normalized().cross(up)
	var post := b.surface_point(b.up_at(entry + side * 1.8 + out.normalized() * 0.5))
	CrabGuardian.new().place(b, post, out, _seed(b, "crab", i + b.critters.size()))


## An eel in a crevice of the grotto's side wall, on the side of the first ledge, near the door.
func _eel(b: MossBall, h: Dictionary, i: int) -> void:
	var centre: Vector3 = h["centre"]
	var up := b.up_at(centre)
	var door: Vector3 = h["door"]
	var to_door := door - centre
	to_door -= up * to_door.dot(up)
	to_door = to_door.normalized()
	var right := to_door.cross(up).normalized()
	var l1: Vector3 = (h["ledges"][0] as Node3D).global_position
	var side := signf((l1 - centre).dot(right))
	if side == 0.0:
		side = 1.0
	var dir := (right * side + to_door * 0.2).normalized()
	CaveEel.new().place(b, centre + up * 1.1, dir, float(h.get("radius", 8.0)), _seed(b, "eel", i))


# --- Running --------------------------------------------------------------------------------

var _placed := false


func _physics_process(dt: float) -> void:
	if not _placed:
		_placed = true
		for c in all_critters():
			c.late_place()
	var g := Game.inst
	if g == null or g.player == null or g.player.ball == null or g.state != "play":
		return
	_check_t -= dt
	if _check_t <= 0.0:
		_check_t = CHECK_DT
		_update_active(g)
	for c in active:
		c.tick(dt)


## Only the axolotl's ball, and only within Critter.ACTIVE_RANGE of him, runs.
func _update_active(g: Game) -> void:
	var p := g.player
	var next := []
	for c in p.ball.critters:
		if c.global_position.distance_to(p.global_position) < Critter.ACTIVE_RANGE:
			next.append(c)
	for c in active:
		if not c in next:
			c.set_active(false)
	for c in next:
		if not c.active:
			c.set_active(true)
	active = next
	# Discovery: a species counts once, when he is close to one he can see.
	for c in active:
		var sp: String = c.species
		if g.species_known(sp) or c.is_hidden():
			continue
		var pt: Vector3 = c.discover_point()
		if p.body_center().distance_to(pt) < c.seen_radius and not c.line_blocked(p.body_center(), pt):
			g.discover_species(sp)


## Wake points of the creatures near the axolotl, nearest first: [[pos, radius, vel, strength]].
func wake_points(near: Vector3, max_points: int) -> Array:
	var pts := []
	for c in active:
		for w in c.wake_points():
			pts.append([(w[0] as Vector3).distance_squared_to(near), w])
	pts.sort_custom(func(a, b): return a[0] < b[0])
	var out := []
	for k in mini(max_points, pts.size()):
		out.append(pts[k][1])
	return out
