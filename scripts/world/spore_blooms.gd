class_name SporeBlooms
extends RefCounted
## Where the toxic spore blooms grow (owner, 2026-10-06; SporeBloom), and running them.
##
## Only the emptiest open ground of each ball: candidate spots are scored by how far they are from
## everything a player comes for or passes through (parasites, Motes, blooms, starfish, upgrades,
## creatures, gates, vortex pads, the ball's arrival and start points); a spot must be at least
## CLEAR_M from all of it, on the bare terrain (not a platform, ravine or cave), and SPACING_M from
## another bloom. One to three a ball by its size (count_for), so they stay occasional discoveries. The tutorial meadow
## (Ball 1's start) is left alone. Placement is fixed by the world (no random draws); each bloom's
## rhythm is seeded from where it grows.

const PER_BALL := 3


## How many a ball of `radius` m gets: 1 on the small ones, 2 on mid-sized, 3 on the largest.
static func count_for(radius: float) -> int:
	return 1 if radius < 40.0 else (2 if radius < 56.0 else PER_BALL)
const CLEAR_M := 18.0
const SPACING_M := 38.0
const START_CLEAR_M := 30.0
const PAD_CLEAR_M := 20.0
const CANDIDATES := 900

var enabled := true
var blooms: Array[SporeBloom] = []
var placed := false


## Every spot a player comes for or passes through on `b`, with how near a bloom may be.
static func keep_out(b: MossBall, vortices: Array, starfish: Array) -> Array:
	var out := []
	for par in b.parasites:
		out.append([b.surface_point(par.spawn_dir), CLEAR_M])
	for m in b.motes:
		if is_instance_valid(m):
			out.append([m.anchor, CLEAR_M])
	for bl in b.blooms:
		out.append([b.surface_point(bl.dir), CLEAR_M])
	for list in [b.upgrades, b.critters, b.gates, b.columns]:
		for n in list:
			if is_instance_valid(n) and n is Node3D:
				out.append([(n as Node3D).global_position, CLEAR_M])
	for st in starfish:
		if is_instance_valid(st) and st.ball == b:
			out.append([st.global_position, CLEAR_M * 0.6])
	for v in vortices:
		if v.ball_a == b:
			out.append([b.surface_point(v.dir_a), PAD_CLEAR_M])
		if v.ball_b == b:
			out.append([b.surface_point(v.dir_b), PAD_CLEAR_M])
	out.append([b.surface_point(b.arrival_dir), START_CLEAR_M])
	out.append([b.surface_point(b.start_dir), START_CLEAR_M])
	return out


## The spots for `b`, best first (deterministic).
static func spots_for(b: MossBall, vortices: Array, starfish: Array, space: PhysicsDirectSpaceState3D) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var ko := keep_out(b, vortices, starfish)
	var scored := []
	for k in CANDIDATES:
		var y := 1.0 - 2.0 * (k + 0.5) / CANDIDATES
		var rr := sqrt(1.0 - y * y)
		var d := Vector3(cos(k * 2.39996) * rr, y, sin(k * 2.39996) * rr)
		# (Ball 1 opens with the tutorial: its meadow stays a safe place to learn.)
		if b.index == 0 and d.angle_to(b.start_dir) < deg_to_rad(40.0):
			continue
		if b.ravine_at(d) != "" or b.on_vortex_pad(d):
			continue
		var at := b.surface_point(d)
		if DrawnBack.in_cave(b, at):
			continue
		var clear := INF
		for e in ko:
			clear = minf(clear, at.distance_to(e[0]) - float(e[1]))
		if clear < 0.0:
			continue
		# Bare terrain only: nothing (a platform, a canopy, a stem) above the spot or under it.
		if space != null:
			var q := PhysicsRayQueryParameters3D.create(b.surface_point(d, 8.0), b.surface_point(d, -1.0), 1 | 2)
			var hit := space.intersect_ray(q)
			if hit.is_empty() or (hit.position as Vector3).distance_to(at) > 0.6:
				continue
		scored.append([clear, d])
	scored.sort_custom(func(a, c) -> bool: return a[0] > c[0])
	for s in scored:
		var d: Vector3 = s[1]
		var ok := true
		for o in out:
			ok = ok and b.surface_point(o).distance_to(b.surface_point(d)) >= SPACING_M
		if ok:
			out.append(d)
		if out.size() >= count_for(b.radius):
			break
	return out


## Grows them (once the world has settled: physics is needed for the bare-terrain check).
func place(balls: Array, vortices: Array, starfish: Array, space: PhysicsDirectSpaceState3D) -> void:
	if placed:
		return
	placed = true
	for b: MossBall in balls:
		for d in spots_for(b, vortices, starfish, space):
			var sb := SporeBloom.new()
			sb.setup(b, d, hash([b.index, roundi(d.x * 1000.0), roundi(d.y * 1000.0), roundi(d.z * 1000.0)]))
			b.add_child(sb)
			blooms.append(sb)


## Every frame of play: only the blooms on his ball, near him, live; others wait where they are.
func update(dt: float, gill: Axolotl) -> void:
	if not enabled or gill == null:
		return
	for sb in blooms:
		if not is_instance_valid(sb) or sb.ball != gill.ball:
			continue
		if sb.global_position.distance_to(gill.global_position) > SporeBloom.ACTIVE_M and sb.state == "idle":
			continue
		sb.step(dt, gill)
