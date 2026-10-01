class_name FoodDirector
extends RefCounted
## Food repopulation (ledger row 11; spec docs/research/2026-09-30-DEVICE_AUDIT.md §D): local
## targets and cooldowns instead of one refill per ball.
##
## Each authored food region keeps `clamp(round(area / 250 m²), 1, 4)` organisms (burrow holes count
## toward the region they lie in). Only regions within LOCAL_M of Gill on his ball refill, one arrival
## per region per 45..90 s cooldown (eating one also starts its region's cooldown, so a region can
## never be farmed), and a ball never holds more than 1.5 x its `food_target`. New organisms
## arrive off camera, drifting down from open water 7..10 m up (burrowers only at holes off camera).
## Every draw comes from the food's own generator, seeded from (run key, ball): food never moves
## the gameplay random sequence, and nothing else moves food's.

const LOCAL_M := 55.0
const AREA_PER_FOOD := 250.0
const TARGET_MIN := 1
const TARGET_MAX := 4
const COOLDOWN_MIN := 45.0
const COOLDOWN_MAX := 90.0
const CAP_MUL := 1.5
## Arrivals keep at least this far from him (and off camera).
const ARRIVE_MIN_M := 10.0
const CHECK_S := 1.0

var key := ""
## The food clock (seconds the food has run: play, never the title or the aquarium).
var t := 0.0
var _check := 0.0
## Ball index -> {"rng": RandomNumberGenerator, "regions": Array[Dictionary]}; each region:
## {dir, radius, area, target, ready, spots: Array (indices into ball.food_spots)}.
var _state := {}
## Every arrival, for tests and the long simulation: {t, ball, region, type, dist, on_camera}.
var arrivals: Array = []


static func region_area(ball_radius: float, radius_deg: float) -> float:
	return TAU * ball_radius * ball_radius * (1.0 - cos(deg_to_rad(radius_deg)))


static func region_target(area: float) -> int:
	return clampi(roundi(area / AREA_PER_FOOD), TARGET_MIN, TARGET_MAX)


static func ball_cap(b: MossBall) -> int:
	return floori(CAP_MUL * b.food_target)


func setup(p_key: String, balls: Array) -> void:
	key = p_key
	_state.clear()
	for b: MossBall in balls:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(Repopulation.unit([key, b.index, "food"]) * 2147483647.0)
		var regions := []
		for reg in b.food_regions:
			var area := region_area(b.radius, float(reg["radius"]))
			regions.append({"dir": (reg["dir"] as Vector3).normalized(), "radius": float(reg["radius"]), "area": area,
					"target": region_target(area), "ready": 0.0, "spots": []})
		# Each burrow hole belongs to the region it lies deepest inside.
		for si in b.food_spots.size():
			var best := -1
			var bk := INF
			for ri in regions.size():
				var k: float = (b.food_spots[si]["dir"] as Vector3).angle_to(regions[ri]["dir"]) / deg_to_rad(regions[ri]["radius"])
				if k < bk:
					bk = k
					best = ri
			if best >= 0:
				regions[best]["spots"].append(si)
		_state[b.index] = {"rng": rng, "regions": regions}


func regions_of(b: MossBall) -> Array:
	return _state[b.index]["regions"]


## Whether a region is near enough to Gill to refill: its nearest edge within LOCAL_M.
func is_local(b: MossBall, reg: Dictionary, gill_pos: Vector3) -> bool:
	var edge_m := b.radius * deg_to_rad(float(reg["radius"]))
	return b.surface_point(reg["dir"]).distance_to(gill_pos) - edge_m <= LOCAL_M


func count_in(b: MossBall, ri: int) -> int:
	var c := 0
	for f in b.foods:
		if is_instance_valid(f) and f.region == ri and f.state != "eaten":
			c += 1
	return c


## The world's first food: every region at its target (a ball's cap permitting), resting near the moss.
func initial(b: MossBall) -> void:
	var regs := regions_of(b)
	# Round the regions one at a time, so a ball whose targets add up past its cap shares it out.
	for k in TARGET_MAX:
		for ri in regs.size():
			if k < int(regs[ri]["target"]) and b.foods.size() < ball_cap(b):
				_spawn(b, ri, true, Vector3.ZERO, null)


## Each frame in play on his ball.
func update(dt: float, b: MossBall, gill_pos: Vector3, cam: Camera3D) -> void:
	t += dt
	_check -= dt
	if _check > 0.0:
		return
	_check = CHECK_S
	b.foods = b.foods.filter(func(f): return is_instance_valid(f))
	if b.foods.size() >= ball_cap(b):
		return
	var regs := regions_of(b)
	var st: Dictionary = _state[b.index]
	for ri in regs.size():
		var reg: Dictionary = regs[ri]
		if t < float(reg["ready"]) or count_in(b, ri) >= int(reg["target"]) or not is_local(b, reg, gill_pos):
			continue
		if _spawn(b, ri, false, gill_pos, cam):
			reg["ready"] = t + (st["rng"] as RandomNumberGenerator).randf_range(COOLDOWN_MIN, COOLDOWN_MAX)
			# (One arrival per look: a ball never fills up in a burst.)
			return


## Gill ate `f`: its region rests a cooldown before the next arrival.
func on_eaten(f: Food) -> void:
	if f.ball == null or not _state.has(f.ball.index) or f.region < 0:
		return
	var st: Dictionary = _state[f.ball.index]
	var reg: Dictionary = st["regions"][f.region]
	reg["ready"] = maxf(float(reg["ready"]), t + (st["rng"] as RandomNumberGenerator).randf_range(COOLDOWN_MIN, COOLDOWN_MAX))


func _pick_type(b: MossBall, rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	var w: Array = b.food_weights
	if r < w[0]:
		return Food.Type.DRIFTER
	if r < w[0] + w[1]:
		return Food.Type.DARTER
	return Food.Type.BURROWER


func _hidden(at: Vector3, up: Vector3, gill_pos: Vector3, cam: Camera3D) -> bool:
	return at.distance_to(gill_pos) >= ARRIVE_MIN_M and not Repopulation.on_camera(cam, at, up, 0.6, 0.6)


func _spawn(b: MossBall, ri: int, initial_: bool, gill_pos: Vector3, cam: Camera3D) -> bool:
	var st: Dictionary = _state[b.index]
	var rng: RandomNumberGenerator = st["rng"]
	var reg: Dictionary = st["regions"][ri]
	var tp := _pick_type(b, rng)
	if tp == Food.Type.BURROWER:
		var free := []
		for si in reg["spots"]:
			var h: Dictionary = b.food_spots[si]
			if h["occupied"]:
				continue
			var at := b.surface_point(h["dir"], h.get("h", 0.0))
			if initial_ or _hidden(at, b.up_at(at), gill_pos, cam):
				free.append(h)
		if free.is_empty():
			tp = Food.Type.DRIFTER
		else:
			var f := Food.new()
			f.setup_burrower(b, free[rng.randi() % free.size()], rng.randi() & 0x7FFFFFFF)
			f.region = ri
			b.add_child(f)
			b.foods.append(f)
			_note(b, ri, f, gill_pos, cam)
			return true
	var rd: Vector3 = reg["dir"]
	for attempt in 8:
		var dir := rd.rotated(MossBall.frame_at(rd, rng.randf() * 360.0).x, deg_to_rad(rng.randf() * float(reg["radius"]) * 0.8))
		# New organisms arrive out of view: they drift or swim down from open water.
		var h := rng.randf_range(0.8, 1.8) if initial_ else rng.randf_range(7.0, 10.0)
		var at := b.surface_point(dir, h)
		if not initial_ and not (_hidden(at, b.up_at(at), gill_pos, cam) and _hidden(b.surface_point(dir, 1.0), dir, gill_pos, cam)):
			continue
		var f := Food.new()
		# (Its position is in the ball's space. Balls 2-7 had
		# their food a ball's offset away from them before this, out of reach in open water.)
		f.setup(b, tp, b.to_local(at), rd, float(reg["radius"]), rng.randi() & 0x7FFFFFFF)
		f.region = ri
		if initial_:
			f.state = "idle"
		b.add_child(f)
		b.foods.append(f)
		_note(b, ri, f, gill_pos, cam)
		return true
	return false


func _note(b: MossBall, ri: int, f: Food, gill_pos: Vector3, cam: Camera3D) -> void:
	var at: Vector3 = b.surface_point(f.hole["dir"], f.hole.get("h", 0.0)) if f.type == Food.Type.BURROWER else f.global_position
	arrivals.append({"t": t, "ball": b.index, "region": ri, "type": f.type, "pos": at, "dist": at.distance_to(gill_pos),
			"alt": b.altitude(at), "on_camera": Repopulation.on_camera(cam, at, b.up_at(at), 0.6, 0.6)})


## Diagnostics: "Food: 9/12 (cap 21), local regions 4 of 7, ready in 12 s".
func summary(b: MossBall, gill_pos: Vector3) -> String:
	var regs := regions_of(b)
	var local := 0
	var want := 0
	for reg in regs:
		if is_local(b, reg, gill_pos):
			local += 1
			want += int(reg["target"])
	return "Food on ball %d: %d (cap %d); %d of %d regions local, local target %d" % [b.index + 1, b.foods.filter(func(f): return is_instance_valid(f)).size(),
			ball_cap(b), local, regs.size(), want]
