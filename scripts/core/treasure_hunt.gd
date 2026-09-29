class_name TreasureHunt
extends RefCounted
## Treasure Hunt (docs/TREASURE_HUNT.md): a replayable postgame search, open once the run reaches
## 100%. Fourteen ridiculous everyday objects, two in each of the seven worlds, found one at a time
## in a shuffled order that moves the player round the whole tank. It is not completion: no ids,
## no catalog change, no effect on the run's percentage, clock or ending.
##
## State lives in the run save as run["treasure"] (additive; RunSave.migrate backfills it, so no
## format or save-schema change). A hunt's seed, its target order and every placement are saved as
## generated, so a reload reproduces the hunt exactly; only starting a NEW hunt generates again.
## Everything random here comes from the hunt's own generator (never the global one gameplay and
## the test bot rely on, never the cosmetic ones).

const KINDS := [
	["duck", "Rubber Duck"], ["fire_hat", "Firefighter's Hat"], ["skillet", "Skillet"], ["microscope", "Microscope"],
	["painting", "Painting"], ["toy_car", "Toy Car"], ["tricycle", "Tricycle"], ["skis", "Skis"],
	["tv", "Television"], ["mower", "Lawn Mower"], ["skateboard", "Skateboard"], ["toaster", "Toaster"],
	["cone", "Traffic Cone"], ["gnome", "Garden Gnome"],
]
const COUNT := 14
const WORLDS := 7
## The first hunt's objects at full size; every hunt after the first at half (never smaller).
const NORMAL_SCALE := 1.0
const HARD_SCALE := 0.5
## Placement: how far from a known-reachable anchor, how far apart a world's two treasures lie
## (fraction of its radius), how far from the previous hunt's spots.
const OFFSET_MIN := 2.5
const OFFSET_MAX := 9.0
const SPREAD := 0.35
const AVOID_PREVIOUS := 6.0
## Terrain, platforms and leaves (what blocks or buries a treasure).
const SOLID_MASK := 1 | 2 | 8


static func kind_name(kind: String) -> String:
	for k in KINDS:
		if k[0] == kind:
			return k[1]
	return kind


## Open once the run is complete (100%, which includes the ending): older saves already at 100%
## qualify with no migration step.
static func eligible(percent: float) -> bool:
	return percent >= 100.0


static func scale_for_hunt(hunt_number: int) -> float:
	return NORMAL_SCALE if hunt_number <= 1 else HARD_SCALE


## A fresh seed from a generator of its own (the global one must not move).
static func new_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi() & 0x7fffffff


# --- The saved state ---------------------------------------------------------------------------

## The run's hunt state (run["treasure"]), with defaults filled in; unknown keys are kept.
static func state_of(run: Dictionary) -> Dictionary:
	if not run.get("treasure") is Dictionary:
		run["treasure"] = {}
	var st: Dictionary = run["treasure"]
	var defaults := {"active": false, "hunt": 0, "seed": 0, "index": 0, "targets": [], "completed_hunts": 0, "last_spots": []}
	for k in defaults:
		if not st.has(k):
			st[k] = defaults[k]
	return st


static func has_hunt(st: Dictionary) -> bool:
	return int(st.get("hunt", 0)) > 0 and (st.get("targets", []) as Array).size() == COUNT


static func is_complete(st: Dictionary) -> bool:
	return has_hunt(st) and int(st["index"]) >= COUNT


static func current(st: Dictionary) -> Dictionary:
	if not has_hunt(st) or is_complete(st):
		return {}
	return (st["targets"] as Array)[int(st["index"])]


static func target_pos(t: Dictionary) -> Vector3:
	var p: Array = t["pos"]
	return Vector3(p[0], p[1], p[2])


## Starts the next hunt: a new seed, a new order, new places (away from the last hunt's), and the
## size that goes with its number. `balls` are the seven worlds (restored: this is postgame).
static func begin_hunt(st: Dictionary, balls: Array, seed_v := -1) -> void:
	var spots := []
	for t in st.get("targets", []):
		spots.append(t["pos"])
	st["last_spots"] = spots
	st["hunt"] = int(st.get("hunt", 0)) + 1
	st["seed"] = new_seed() if seed_v < 0 else seed_v
	st["index"] = 0
	st["scale"] = scale_for_hunt(int(st["hunt"]))
	var avoid: Array[Vector3] = []
	for p in spots:
		avoid.append(Vector3(p[0], p[1], p[2]))
	st["targets"] = generate(int(st["seed"]), float(st["scale"]), balls, avoid)
	st["active"] = true


## Records one find (the caller saves at once, before any celebration): exactly one step forward.
## Returns false (and changes nothing) if `index` is not the current target.
static func collect(st: Dictionary, index: int) -> bool:
	if not has_hunt(st) or is_complete(st) or index != int(st["index"]):
		return false
	st["index"] = index + 1
	if int(st["index"]) >= COUNT:
		st["completed_hunts"] = int(st.get("completed_hunts", 0)) + 1
	return true


# --- Generation --------------------------------------------------------------------------------

## The whole hunt from its seed: which object goes where and in what order. Deterministic for the
## seed and the worlds' geometry. Every world gets exactly two; the order is shuffled across worlds
## and never visits the same world twice in a row.
static func generate(seed_v: int, scale: float, balls: Array, avoid: Array[Vector3] = []) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var kinds: Array = []
	for k in KINDS:
		kinds.append(k[0])
	_shuffle(kinds, rng)
	var worlds := world_order(rng)
	var targets: Array = []
	var chosen: Array[Vector3] = []
	var cands := {}
	for i in COUNT:
		var w: int = worlds[i]
		var b: MossBall = balls[w]
		if not cands.has(w):
			cands[w] = candidates(b, scale, rng)
		var pick := _choose(b, cands[w], chosen, avoid, rng)
		var pos: Vector3 = pick["pos"]
		chosen.append(pos)
		targets.append({"kind": kinds[i], "world": w, "pos": [snappedf(pos.x, 0.001), snappedf(pos.y, 0.001), snappedf(pos.z, 0.001)],
				"yaw": snappedf(rng.randf() * 360.0, 0.1), "scale": scale})
	return targets


## Fourteen slots, two per world, shuffled with no world twice in a row (and never world by world).
static func world_order(rng: RandomNumberGenerator) -> Array:
	for attempt in 64:
		var seq: Array = []
		for w in WORLDS:
			seq.append(w)
			seq.append(w)
		_shuffle(seq, rng)
		var ok := true
		for i in range(1, seq.size()):
			if seq[i] == seq[i - 1]:
				ok = false
				break
		if ok:
			return seq
	# (Practically unreachable: a fixed interleave that still visits every world twice.)
	return [0, 3, 6, 2, 5, 1, 4, 0, 3, 6, 2, 5, 1, 4]


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## Proven-reachable anchors in a world: its blooms (the bot and the player respawn there), its
## burrower holes and its arrival point. Treasures go a short, checked walk from one of them.
static func anchors(b: MossBall) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for bl in b.blooms:
		if is_instance_valid(bl):
			out.append(b.surface_point(b.up_at((bl as Node3D).global_position)))
	for fs in b.food_spots:
		out.append(b.surface_point(fs["dir"]))
	out.append(b.surface_point(b.arrival_dir))
	return out


## Valid spots in a world for a treasure of this scale: [{pos, cover}], deterministic for the rng.
static func candidates(b: MossBall, scale: float, rng: RandomNumberGenerator) -> Array:
	var out := []
	for a in anchors(b):
		if not spot_ok(b, a, 0.5):
			continue
		var up := b.up_at(a)
		var fr := MossBall.frame_at(up, 0.0)
		for k in 8:
			var ang := rng.randf() * TAU
			var dist := rng.randf_range(OFFSET_MIN, OFFSET_MAX)
			var dir := (fr.z.rotated(up, ang)).normalized()
			var p := b.surface_point((a + dir * dist - b.global_position).normalized())
			if spot_ok(b, p, scale) and path_ok(b, a, p):
				out.append({"pos": p, "cover": cover(b, p, scale)})
	return out


static func _choose(b: MossBall, cands: Array, chosen: Array[Vector3], avoid: Array[Vector3], rng: RandomNumberGenerator) -> Dictionary:
	var spread := b.radius * SPREAD
	var tiers := [[], [], []]
	for c in cands:
		var p: Vector3 = c["pos"]
		var near := false
		for q in chosen:
			if q.distance_to(p) < spread:
				near = true
		if near:
			continue
		var repeat := false
		for q in avoid:
			if q.distance_to(p) < AVOID_PREVIOUS:
				repeat = true
		# Partly hidden (some cover, not boxed in) first; then any; then even a repeat of last time.
		var tier := 2 if repeat else (0 if int(c["cover"]) >= 1 and int(c["cover"]) <= 5 else 1)
		tiers[tier].append(c)
	for t in tiers:
		if not t.is_empty():
			return t[rng.randi() % t.size()]
	# No spread-out spot left (only with very few candidates): the nearest-to-valid fallback is any
	# candidate at all, and failing that the arrival point, which is always reachable.
	if not cands.is_empty():
		return cands[rng.randi() % cands.size()]
	return {"pos": b.surface_point(b.arrival_dir), "cover": 0}


# --- Validation (also used to check saved spots on load) --------------------------------------

## A treasure of `scale` can rest at ground point `p`: on the terrain surface (not buried, not
## floating), not on or in a ravine, fairly level, nothing solid where it would sit, room above for
## him to come at it, inside the tank.
static func spot_ok(b: MossBall, p: Vector3, scale: float) -> bool:
	var dir := (p - b.global_position).normalized()
	if b.ravine_at(dir) != "" or b.ravine_carve(dir) > 0.15:
		return false
	if absf(b.altitude(p)) > 0.5:
		return false
	var box := AABB(Aquarium.TANK_MIN, Aquarium.TANK_MAX - Aquarium.TANK_MIN)
	if not box.has_point(p):
		return false
	var space := b.get_world_3d().direct_space_state
	var up := b.up_at(p)
	# The ground itself, where the terrain says it is (not a rock or ledge above it).
	var g := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + up * 3.0, p - up * 1.0, SOLID_MASK))
	if g.is_empty() or (g["position"] as Vector3).distance_to(p) > 0.35 or (g["normal"] as Vector3).dot(up) < 0.8:
		return false
	# Nothing where it sits.
	var size := 1.3 * scale
	var sh := SphereShape3D.new()
	sh.radius = size * 0.45
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = Transform3D(Basis(), p + up * (size * 0.55 + 0.08))
	q.collision_mask = SOLID_MASK
	if not space.intersect_shape(q, 1).is_empty():
		return false
	# Room for him to reach it (a canopy far overhead is fine).
	var head := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + up * 0.2, p + up * 1.4, SOLID_MASK))
	return head.is_empty()


## A walk from a reachable point `a` to `p` along the ground: no ravine, no step he cannot take,
## nothing solid in the way at body height.
static func path_ok(b: MossBall, a: Vector3, p: Vector3) -> bool:
	var space := b.get_world_3d().direct_space_state
	var n := int(ceil(a.distance_to(p) / 0.8)) + 1
	var prev := a
	var prev_h := b.terrain_height(b.up_at(a))
	for i in range(1, n + 1):
		var d := (a.lerp(p, float(i) / n) - b.global_position).normalized()
		if b.ravine_at(d) != "" or b.ravine_carve(d) > 0.15:
			return false
		var h := b.terrain_height(d)
		if absf(h - prev_h) > 0.6:
			return false
		var q := b.surface_point(d)
		var up := b.up_at(q)
		var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(prev + b.up_at(prev) * 0.45, q + up * 0.45, SOLID_MASK))
		if not r.is_empty():
			return false
		prev = q
		prev_h = h
	return true


## How hidden a spot is: of eight directions at the object's middle, how many are blocked within
## 3 m (0 open ground .. 8 boxed in).
static func cover(b: MossBall, p: Vector3, scale: float) -> int:
	var space := b.get_world_3d().direct_space_state
	var up := b.up_at(p)
	var fr := MossBall.frame_at(up, 0.0)
	var o := p + up * (0.6 * scale + 0.1)
	var n := 0
	for k in 8:
		var dir := fr.z.rotated(up, TAU * k / 8.0)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + dir * 3.0, SOLID_MASK)).is_empty():
			n += 1
	return n


## A saved spot no longer valid (the world changed under it, or the save was damaged): another
## valid spot in the same world for the same object, chosen deterministically from the hunt's seed
## and the target's index. The object, the order and the progress are kept.
static func recover(st: Dictionary, index: int, balls: Array) -> bool:
	var t: Dictionary = (st["targets"] as Array)[index]
	var b: MossBall = balls[int(t["world"])]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(st["seed"]), index, "recover"])
	var scale := float(t.get("scale", 1.0))
	var others: Array[Vector3] = []
	for j in (st["targets"] as Array).size():
		if j != index:
			others.append(target_pos((st["targets"] as Array)[j]))
	var pick := _choose(b, candidates(b, scale, rng), others, [] as Array[Vector3], rng)
	var pos: Vector3 = pick["pos"]
	t["pos"] = [snappedf(pos.x, 0.001), snappedf(pos.y, 0.001), snappedf(pos.z, 0.001)]
	t["recovered"] = int(t.get("recovered", 0)) + 1
	return true
