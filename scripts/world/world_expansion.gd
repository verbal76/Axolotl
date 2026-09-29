class_name WorldExpansion
## Expansion 4's four new moss balls (docs/WORLD.md). Each is reached by its own vortex from a
## ball already in the world, and each has its own size, silhouette, palette, vegetation, route
## structure and landmark:
##   4 Terrace Steps  (r 18, off Mossy Meadow)  open low growth; stepped terraces, a stone arch,
##                    a ridge walk; a grotto.
##   5 Reed Canyon    (r 26, off Current Hollows) a canyon between two ridges full of tall reeds,
##                    a natural bridge between the crests; a grotto at the canyon's end.
##   6 Canopy Spire   (r 16, off Giant Stems)    a small ball with one great stem: a spiral climb to
##                    a canopy crown; overhanging shelves as a second climb; no cave.
##   7 Hollow Grotto  (r 22, off Terrace Steps)  dim basalt: two grottoes, overhanging shelves,
##                    low ridges with vegetation corridors between exposed rock.
## Positions are authored relative to where the vortex arrives (the "arrival" lat/lon), so each
## ball reads from its entrance.

## The Canopy Spire's leaf spiral: a quarter turn per leaf (Expansion 6; was 72 degrees).
const SPIRE_TURN := 90.0


## lat/lon of the point `dlat`/`dlon` degrees from where the vortex from `parent` arrives.
static func _rel(i: int, parent: int, dlat: float, dlon: float) -> Vector2:
	var arr := Levels._latlon(Levels._vortex_dir(i, parent))
	return Vector2(clampf(arr.x + dlat, -85.0, 85.0), wrapf(arr.y + dlon, -180.0, 180.0))


static func _dir(v: Vector2) -> Vector3:
	return MossBall.dir_ll(v.x, v.y)


## Vegetation shared helper: a light carpet of the short family over the ball, sparing landmarks.
static func _short_cover(lb: LevelBuilder, count: int, seed_v: int, clear: Callable, stands: Callable = Callable()) -> void:
	var b := lb.ball
	var mat := Vegetation.material(b, "short")
	var ok := func(dd: Vector3) -> bool: return not clear.call(dd) and (not stands.is_valid() or stands.call(dd))
	b.scatter(MeshLib.tuft_mesh(5, 0.07, 0.36, 0.12, seed_v, 3, 0.3), mat, count, seed_v, 0.8, 1.3, ok, 70.0)


# =========================================================================================
# 4 — TERRACE STEPS
# =========================================================================================

static func terrace_steps(lb: LevelBuilder) -> void:
	var b := lb.ball
	var R := func(dlat: float, dlon: float) -> Vector2: return _rel(3, 0, dlat, dlon)
	b.food_weights = [0.5, 0.35, 0.15]
	b.food_target = 14
	var land: Vector2 = R.call(0, 0)
	lb.hill(land.x + 30, land.y + 150, 14.0, 2.0)
	lb.hill(land.x - 60, land.y + 120, 12.0, 1.7)
	# World expansion (radius 18 -> 36): the Stone Field, an upland with a sunken basin crossed
	# on stone columns (registered before anything stands on the ground).
	var sf: Vector2 = R.call(-45, 20)
	var sf_dir := _dir(sf)
	b.add_plateau(sf_dir, lb.m2deg(18.0) * PI / 180.0, 3.0, 8.0)
	var sfp := func(x: float, z: float) -> Vector3: return lb.at(sf.x, sf.y, 0.0, x, 0, z).origin
	lb.ravine([Levels._latlon(b.up_at(sfp.call(-4.6, 0))), Levels._latlon(b.up_at(sfp.call(4.6, 0)))], 9.0, 3.0, 1.2, "b4.stone_field")

	lb.zone("landing", land.x, land.y, 26)
	# (Clear of the vortex to Hollow Grotto, which opens about 25 degrees south-west of here.)
	var tz: Vector2 = R.call(22, 38)
	lb.zone("terraces", tz.x, tz.y, 28)
	var az: Vector2 = R.call(-34, -48)
	lb.zone("arch", az.x, az.y, 26)
	var rz: Vector2 = R.call(40, -10)
	lb.zone("ridge", rz.x, rz.y, 26)
	var fz: Vector2 = R.call(-10, 170)
	lb.zone("far", fz.x, fz.y, 40)

	# Landing: an open plain.
	var p: Vector2 = R.call(-10, 22)
	lb.parasite(Parasite.Kind.SMALL, "landing", p.x, p.y, 8.0)
	p = R.call(12, -18)
	lb.mote("landing", p.x, p.y)
	p = R.call(-7, 7)
	lb.bloom(p.x, p.y)

	# The terraces: three steps, each one plain jump; the crown holds a mote and a bloom.
	var tiers := lb.terrace(tz.x, tz.y, [[7.0, 1.2], [4.2, 2.4], [2.0, 3.6]])
	lb.mote("terraces", tz.x, tz.y + 1.0, 3.6, 0.8)
	lb.bloom(tz.x - 0.8, tz.y - 1.2, 3.6)
	var up_t := b.up_at(tiers[0].global_position)
	var side := MossBall.frame_at(up_t, 0.0).x
	# Tiers follow the ball's curve, so a point on one is its height above the local ground.
	var tp := func(r: float, h: float) -> Vector3: return b.surface_point(b.up_at(tiers[0].global_position + side * r), h)
	lb.route("terraces", tp.call(9.2, 0.0), [tp.call(5.8, 1.25), tp.call(2.6, 2.45), tp.call(0.4, 3.65)], ["terraces"], "terrace crown")
	p = R.call(36, 60)
	lb.parasite(Parasite.Kind.MEDIUM, "terraces", p.x, p.y, 9.0)
	p = R.call(6, 58)
	lb.mote("terraces", p.x, p.y)

	# A lower double terrace with a parasite at its foot.
	var t2: Vector2 = R.call(-40, 92)
	lb.terrace(t2.x, t2.y, [[5.0, 1.0], [2.8, 2.1]])
	p = R.call(-48, 80)
	lb.parasite(Parasite.Kind.SMALL, "terraces", p.x, p.y, 7.0)

	# The arch: walk over it or under it; a mote waits under it and another on top.
	var a0: Vector2 = R.call(-54, -48)
	var a1: Vector2 = R.call(-16, -48)
	var arch := lb.arch(a0.x, a0.y, a1.x, a1.y, 2.2, 2.4, 1.1)
	var line: Array = arch.get_meta("top_line")
	var mid: Vector3 = line[line.size() / 2]
	var ll := Levels._latlon(b.up_at(mid))
	lb.mote("arch", ll.x, ll.y + lb.m2deg(0.95) / cos(deg_to_rad(ll.x)), -1.4, 1.0)   # beneath it (its search starts under the slab)
	lb.mote_xf("arch", Transform3D(MossBall.frame_at(b.up_at(mid), 0.0), mid + b.up_at(mid) * 0.5), 0.5)
	var a_start: Vector3 = b.surface_point(b.up_at(line[0]), 0.0) - (line[3] - line[0]).normalized() * 1.2
	lb.route("arch", b.surface_point(b.up_at(a_start), 0.0), [line[2], line[4], line[9], line[line.size() / 2]], ["arch"], "arch top")
	p = R.call(-30, -70)
	lb.parasite(Parasite.Kind.SMALL, "arch", p.x, p.y, 8.0)

	# The ridge walk: a crest route above the landing, ramps at both ends.
	var r0: Vector2 = R.call(34, -60)
	var r1: Vector2 = R.call(46, 30)
	var ridge := lb.ridge(r0.x, r0.y, r1.x, r1.y, 2.2, 6.0, 1.8, 41)
	var crest: Array = ridge.get_meta("crest")
	var cm: Vector3 = crest[crest.size() / 2]
	lb.mote_xf("ridge", Transform3D(MossBall.frame_at(b.up_at(cm), 0.0), cm + b.up_at(cm) * 0.5), 0.6)
	lb.route("ridge", crest[0], crest.slice(1, crest.size() / 2 + 1, 3) + [cm], ["ridge"], "ridge crest")
	p = R.call(52, -30)
	lb.parasite(Parasite.Kind.SMALL, "ridge", p.x, p.y, 8.0)

	# The far side: a grotto with a pearl.
	var cv: Vector2 = R.call(-8, 172)
	lb.cave(cv.x, cv.y, 0.0, 7.2, "pearl")
	p = R.call(24, 150)
	lb.parasite(Parasite.Kind.MEDIUM, "far", p.x, p.y, 10.0).make_spitter()
	p = R.call(20, -150)
	lb.mote("far", p.x, p.y)
	p = R.call(30, 140)
	lb.bloom(p.x, p.y)

	lb.freeze_ids()

	# ---- World expansion: Terrace Steps at radius 36 ------------------------------------------
	var gz: Vector2 = R.call(40, 120)
	lb.zone("grand", gz.x, gz.y, 22)
	lb.zone("field", sf.x, sf.y, 18)
	# The Grand Terraces (four broad tiers, the safe way up: walk each ring round to its next step)
	# and the Twin Terrace, joined at the third tier by a natural stone bridge.
	var grand := lb.terrace(gz.x, gz.y, [[10.0, 1.2], [7.5, 2.4], [5.0, 3.6], [2.6, 4.8]])
	var gbase: Vector3 = (grand[0] as Node3D).global_position
	var gup := b.up_at(gbase)
	var gfr := MossBall.frame_at(gup, 0.0)
	var gp := func(dirv: Vector3, r: float, h: float) -> Vector3: return b.surface_point(b.up_at(gbase + dirv * r), h)
	lb.route("grand terraces", gp.call(gfr.x, 11.9, 0.0), [gp.call(gfr.x, 8.7, 1.2), gp.call(gfr.x, 6.2, 2.4), gp.call(gfr.x, 3.8, 3.6), gp.call(gfr.x, 0.6, 4.8)], ["grand"], "the Grand Terraces' crown")
	var gtop: Vector3 = gp.call(gfr.x, 0.0, 4.8)
	lb.mote_xf("grand", Transform3D(MossBall.frame_at(b.up_at(gtop), 0.0), gtop + b.up_at(gtop) * 0.6), 0.5)
	lb.bloom_xf(Transform3D(MossBall.frame_at(b.up_at(gtop), 0.0), gp.call(-gfr.x, 1.4, 4.8)))
	var twin_dir := b.up_at(gbase + gfr.z * 19.0)
	var twin_ll := Levels._latlon(twin_dir)
	var twin := lb.terrace(twin_ll.x, twin_ll.y, [[6.0, 1.2], [4.0, 2.4], [2.2, 3.6]])
	var tbase: Vector3 = (twin[0] as Node3D).global_position
	var bridge_a: Vector3 = gp.call(gfr.z, 4.4, 3.6)
	var tdir := (gbase - tbase).normalized()
	var bridge_b := b.surface_point(b.up_at(tbase + tdir * 1.6), 3.6)
	var gbr := lb.bridge(bridge_a, bridge_b, 0.4, 2.0, 0.8)
	var gbl: Array = gbr.get_meta("top_line")
	# (Up the side away from the bridge, round the third tier's ring to it, and across.)
	var ring := []
	for k in range(1, 5):
		ring.append(gp.call(gfr.x.slerp(gfr.z, k / 4.0).normalized(), 3.9, 3.6))
	lb.route("terrace bridge", gp.call(gfr.x, 11.9, 0.0), [gp.call(gfr.x, 8.7, 1.2), gp.call(gfr.x, 6.2, 2.4), gp.call(gfr.x, 3.9, 3.6)] + ring + [bridge_a, gbl[6], gbl[10], gbl[14], bridge_b],
			["grand"], "the Twin Terrace over the bridge")
	var tt := b.surface_point(b.up_at(tbase), 3.6)
	lb.mote_xf("grand", Transform3D(MossBall.frame_at(b.up_at(tt), 0.0), tt + b.up_at(tt) * 0.6), 0.4)
	lb.parasite(Parasite.Kind.MEDIUM, "grand", gz.x - 16, gz.y - 6, 4.0)
	lb.parasite(Parasite.Kind.SMALL, "grand", gz.x + 12, gz.y + 22, 4.0)
	lb.mote("grand", gz.x - 20, gz.y + 20)
	# The Stone Field: across the basin on stone columns (the technical way, a mote on the middle
	# one), round its rim (the safe way), or, once the landing heals, over the broad stones that
	# rise out of the basin floor.
	var cols := [[-1.5, -4.0], [1.2, -1.6], [-1.2, 1.0], [1.4, 3.6]]
	var ctops := []
	for c in cols:
		var cd := b.up_at(sfp.call(c[0], c[1]))
		lb.stone_column(cd, 0.75, 3.1)
		ctops.append(b.surface_point(cd, 3.1))
	var rim_n := b.surface_point(b.up_at(sfp.call(-1.5, -6.9)))
	var rim_s := b.surface_point(b.up_at(sfp.call(1.4, 6.9)))
	lb.route("stone field", rim_n, ctops, ["field"], "the far column")
	lb.bot_hints[lb.bot_hints.size() - 1]["exit"] = [rim_s]
	lb.crossings.append({"a": rim_n, "b": rim_s, "stones": ctops, "gate": null})
	var mcol: Vector3 = ctops[3]
	lb.mote_xf("field", Transform3D(MossBall.frame_at(b.up_at(mcol), 0.0), mcol + b.up_at(mcol) * 0.5), 0.3)
	var first_stone: RestorationGate = null
	var rtops := []
	for z in [-3.9, -1.3, 1.3, 3.9]:
		var rs := lb.rising_stone("landing", b.up_at(sfp.call(4.2, z)), 1.3, 3.05)
		rtops.append(rs.get_meta("top_point"))
		if first_stone == null:
			first_stone = rs
	var rs_a := b.surface_point(b.up_at(sfp.call(4.2, -6.9)))
	var rs_b := b.surface_point(b.up_at(sfp.call(4.2, 6.9)))
	lb.crossings.append({"a": rs_a, "b": rs_b, "gate": first_stone})
	# (Audited as the risen path: until the landing heals the stones are buried.)
	lb.bot_hints.append({"route": "risen stones", "audit": true, "gated": true, "start": rs_a, "tops": rtops + [rs_b], "zones": [], "goal": "across the Stone Field"})
	lb.parasite(Parasite.Kind.SMALL, "field", sf.x + 12, sf.y - 14, 4.0)
	lb.parasite(Parasite.Kind.SMALL, "field", sf.x - 12, sf.y + 16, 4.0)
	lb.mote("field", sf.x + 14, sf.y + 10)
	lb.bloom(sf.x + 16, sf.y - 2)
	# More of the landing, the arch and the far side.
	p = R.call(-20, -20)
	lb.parasite(Parasite.Kind.SMALL, "landing", p.x, p.y, 5.0)
	p = R.call(18, 20)
	lb.mote("landing", p.x, p.y)
	p = R.call(-40, -70)
	lb.mote("arch", p.x, p.y)
	p = R.call(0, 140)
	lb.parasite(Parasite.Kind.SMALL, "far", p.x, p.y, 5.0)
	p = R.call(-30, 170)
	lb.mote("far", p.x, p.y)
	# The Coral Shelves: three shelves stepping up out of a coral bed, a Mote on each.
	var csz: Vector2 = R.call(-12, -128)
	lb.zone("coralsh", csz.x, csz.y, 14)
	var csp := func(x: float, z: float) -> Transform3D: return lb.at(csz.x, csz.y, 0.0, x, 0, z)
	var cshelves := [[0.0, 0.0, 1.3, 1.9], [3.4, 1.0, 2.5, 1.8], [5.6, -1.8, 3.7, 1.8]]
	var cstops := []
	for cs in cshelves:
		var cd := b.up_at((csp.call(cs[0], cs[1]) as Transform3D).origin)
		var cll := Levels._latlon(cd)
		lb.shelf(cll.x, cll.y, cs[2], cs[3], 0.9)
		var ctop := b.surface_point(cd, cs[2])
		cstops.append(ctop)
		if cs[2] != 2.5:
			lb.mote_xf("coralsh", Transform3D(MossBall.frame_at(b.up_at(ctop), 0.0), ctop + b.up_at(ctop) * 0.5), 0.4)
	lb.route("coral shelves", b.surface_point(b.up_at((csp.call(-3.1, 0) as Transform3D).origin)), cstops, ["coralsh"], "the highest coral shelf")
	lb.mote_xf("coralsh", csp.call(3, 6), 1.2)
	lb.parasite_xf(Parasite.Kind.SMALL, "coralsh", csp.call(-5, 5), 3.0)
	lb.parasite_xf(Parasite.Kind.MEDIUM, "coralsh", csp.call(4, 7), 3.0)
	lb.mote_xf("coralsh", csp.call(-2, -6), 1.2)
	lb.bloom_xf(csp.call(-6, -3))
	var cbed := _dir(csz)
	var in_bed := func(dd: Vector3) -> bool: return dd.angle_to(cbed) < deg_to_rad(lb.m2deg(9.0))
	for k in 2:
		var col: Array = Levels.ACCENTS[3][k]
		var cmat := b.make_veg_material(col[0], col[1], Vegetation.family_params("short", 0.45).merged({"sway": 0.12, "wake_gain": 0.7, "cam_fade": 1.0}, true))
		b.coral_nodes += b.scatter(MeshLib.coral_mesh(5 + k * 2, 0.75 + k * 0.15, 970 + k), cmat, 160, 970 + k, 1.1, 2.4, in_bed, 70.0)

	for r in [[land.x, land.y, 24], [tz.x + 20, tz.y + 30, 20], [fz.x, fz.y, 24], [gz.x, gz.y, 16], [sf.x, sf.y, 14], [csz.x, csz.y, 10]]:
		lb.food_region(r[0], r[1], r[2])
	Levels._holes(lb, 20, 301, [[_dir(tz), 18], [_dir(cv), 14], [_dir(az), 14], [_dir(gz), 16], [sf_dir, 14], [twin_dir, 8]])
	# Open, low growth: sunny and readable; a few medium clumps.
	var clear := Levels._veg_keep_clear(lb, [[_dir(gz), 16.0], [twin_dir, 10.0], [sf_dir, 16.0]])
	_short_cover(lb, 7000, 311, clear)
	Vegetation.field(b, "medium", _dir(R.call(-28, 130)), 12.0, 700, 312, {"avoid": clear, "clumps": 8})
	Vegetation.field(b, "medium", _dir(R.call(10, -110)), 10.0, 500, 313, {"avoid": clear, "clumps": 6})


# =========================================================================================
# 5 — REED CANYON
# =========================================================================================

static func reed_canyon(lb: LevelBuilder) -> void:
	var b := lb.ball
	var R := func(dlat: float, dlon: float) -> Vector2: return _rel(4, 1, dlat, dlon)
	b.food_weights = [0.45, 0.3, 0.25]
	b.food_target = 15
	var land: Vector2 = R.call(0, 0)
	# World expansion (radius 26 -> 52): the Reed Maze, an upland on the far side threaded by two
	# narrow ravines (registered before anything stands on the ground).
	var mz: Vector2 = R.call(12, -128)
	var mz_dir := _dir(mz)
	b.add_plateau(mz_dir, lb.m2deg(21.0) * PI / 180.0, 3.0, 7.0)
	var mzp := func(x: float, z: float) -> Vector3: return lb.at(mz.x, mz.y, 0.0, x, 0, z).origin
	var mll := func(x: float, z: float) -> Vector2: return Levels._latlon(b.up_at(mzp.call(x, z)))
	lb.ravine([mll.call(-9, -6), mll.call(-3, -3), mll.call(3, -5), mll.call(9, -2)], 2.2, 3.0, 1.0, "b5.maze_west")
	lb.ravine([mll.call(-8, 5), mll.call(-2, 7), mll.call(4, 4), mll.call(8, 7)], 2.2, 3.0, 1.0, "b5.maze_east")
	lb.zone("landing", land.x, land.y, 24)
	var cz: Vector2 = R.call(0, 58)
	lb.zone("canyon", cz.x, cz.y, 30)
	var nz: Vector2 = R.call(14, 58)
	lb.zone("crests", nz.x, nz.y, 30)
	var ez: Vector2 = R.call(0, 118)
	lb.zone("end", ez.x, ez.y, 26)
	var fz: Vector2 = R.call(10, -130)
	lb.zone("far", fz.x, fz.y, 45)

	var p: Vector2 = R.call(-8, 10)
	lb.bloom(p.x, p.y)
	p = R.call(12, -20)
	lb.mote("landing", p.x, p.y)
	p = R.call(-14, -12)
	lb.parasite(Parasite.Kind.SMALL, "landing", p.x, p.y, 8.0)

	# The canyon: two ridges, reeds between them.
	# (At the new size the ridges stand 7 degrees either side: the canyon keeps its width in
	# metres and doubles in length.)
	var n0: Vector2 = R.call(7, 22)
	var n1: Vector2 = R.call(7, 96)
	var s0: Vector2 = R.call(-7, 22)
	var s1: Vector2 = R.call(-7, 96)
	var north := lb.ridge(n0.x, n0.y, n1.x, n1.y, 3.0, 6.5, 1.9, 51, 0.22)
	var south := lb.ridge(s0.x, s0.y, s1.x, s1.y, 2.6, 6.0, 1.8, 52, 0.22)
	var nc: Array = north.get_meta("crest")
	var sc: Array = south.get_meta("crest")
	# The natural bridge between the crests, at the canyon's middle.
	var bi := nc.size() / 2
	var bridge := lb.bridge(nc[bi], sc[bi], 0.5, 2.0, 0.9)
	var bl: Array = bridge.get_meta("top_line")
	var bm: Vector3 = bl[bl.size() / 2]
	lb.mote_xf("crests", Transform3D(MossBall.frame_at(b.up_at(bm), 0.0), bm + b.up_at(bm) * 0.5), 0.5)
	# The bloom a few steps further along the bridge, on its real top.
	var bb: Vector3 = bl[bl.size() / 2 + 3]
	lb.bloom_xf(Transform3D(MossBall.frame_at(b.up_at(bb), 0.0), bb))
	lb.route("bridge", nc[0], nc.slice(1, bi, 3) + [nc[bi], bl[3], bl[6], bm], ["crests"], "canyon bridge")
	# Across the bridge onto the south crest and along it (audit only).
	lb.bot_hints.append({"route": "south crest", "audit": true, "branch": true, "start": bm,
			"tops": bl.slice(bl.size() / 2 + 3, bl.size() - 1, 3) + [sc[bi]] + sc.slice(bi + 3, sc.size(), 3) + [sc[sc.size() - 1]], "zones": [], "goal": "south crest"})
	lb.bot_hints.append({"route": "south crest west", "audit": true, "branch": true, "start": sc[bi],
			"tops": sc.slice(bi - 3, 0, -3) + [sc[0]], "zones": [], "goal": "south crest"})
	var ncf: Vector3 = nc[nc.size() - 4]
	lb.mote_xf("crests", Transform3D(MossBall.frame_at(b.up_at(ncf), 0.0), ncf + b.up_at(ncf) * 0.5), 0.5)
	lb.route("north crest", nc[nc.size() - 1], [nc[nc.size() - 2], ncf], ["crests"], "north crest end")
	# In the reeds: two motes and the parasites whose movement shows in the reeds.
	p = R.call(1, 44)
	lb.mote("canyon", p.x, p.y)
	p = R.call(-2, 76)
	lb.mote("canyon", p.x, p.y)
	p = R.call(0, 62)
	lb.parasite(Parasite.Kind.LARGE, "canyon", p.x, p.y, 7.0)
	p = R.call(2, 36)
	lb.parasite(Parasite.Kind.MEDIUM, "canyon", p.x, p.y, 6.0)

	# The canyon's end: a grotto.
	var cv: Vector2 = R.call(0, 116)
	lb.cave(cv.x, cv.y, 90.0, 8.0, "pearl")
	p = R.call(-18, 124)
	lb.parasite(Parasite.Kind.SMALL, "end", p.x, p.y, 8.0)
	p = R.call(18, 132)
	lb.mote("end", p.x, p.y)

	# The far side: open slopes.
	lb.hill(fz.x - 20, fz.y - 10, 16.0, 2.4)
	lb.hill(fz.x - 25, fz.y + 30, 16.0, 2.1)
	# (Moved clear of the Reed Maze's ravines; its id is frozen, so moving it is safe.)
	p = R.call(-6, -152)
	lb.mote("far", p.x, p.y)
	p = R.call(-4, -120)
	lb.parasite(Parasite.Kind.MEDIUM, "far", p.x, p.y, 10.0).make_spitter()
	p = R.call(-20, -150)
	lb.bloom(p.x, p.y)

	lb.freeze_ids()

	# ---- World expansion: Reed Canyon at radius 52 ---------------------------------------------
	lb.zone("maze", mz.x, mz.y, 18)
	lb.zone("secret", mz.x + 14, mz.y - 4, 8)
	# The Reed Maze: two narrow ravines hidden in dense reeds (the reeds stop at their edges, so
	# the gaps show). Over the western one on a fallen log; a running jump + burst crosses either;
	# or walk round their ends. A reed stalker hunts here.
	var log_a := b.surface_point(b.up_at(mzp.call(-3, -5.6)))
	var log_b := b.surface_point(b.up_at(mzp.call(-3, -0.4)))
	var logb := lb.stem_xf(Transform3D(Basis((log_b - log_a).normalized().cross(b.up_at(log_a)).normalized(), (log_b - log_a).normalized(),
			(log_b - log_a).normalized().cross(b.up_at(log_a)).normalized().cross((log_b - log_a).normalized())), log_a + b.up_at(log_a) * 0.35 - (log_b - log_a).normalized() * 0.8),
			log_a.distance_to(log_b) + 1.1, 0.42, 0.36, true, 0.0)
	logb.set_meta("floats_by_design", "a fallen log across a ravine")
	logb.remove_meta("grounded")   # (it spans the ravine: no ground under its middle, by design)
	lb.crossings.append({"a": log_a, "b": log_b, "gate": null})
	# (Placed in the maze's own metres, clear of both cuts: north of the western one, on the strip
	# between them, south of the eastern one, and past their ends.)
	var mzxf := func(x: float, z: float) -> Transform3D: return lb.at(mz.x, mz.y, 0.0, x, 0, z)
	lb.parasite_xf(Parasite.Kind.SMALL, "maze", mzxf.call(6, -11), 3.0)
	lb.parasite_xf(Parasite.Kind.MEDIUM, "maze", mzxf.call(-6, 11.5), 3.0)
	# (Not on the narrow strip between the cuts: a fight there is a fall waiting to happen.)
	lb.parasite_xf(Parasite.Kind.SMALL, "maze", mzxf.call(14, -9), 2.5)
	lb.mote_xf("maze", mzxf.call(-13, 0.5), 1.0)
	lb.mote_xf("maze", mzxf.call(13, 1.5), 1.0)
	lb.mote_xf("maze", mzxf.call(0, 13), 1.0)
	lb.bloom_xf(mzxf.call(-10, -12))
	# The Secret Clearing: a quiet pocket through a tunnel in the reeds (no parasites).
	var sc_c: Vector2 = Vector2(mz.x + 14, mz.y - 4)
	lb.mote("secret", sc_c.x, sc_c.y + 2)
	lb.mote("secret", sc_c.x - 2, sc_c.y - 2)
	lb.bloom(sc_c.x + 1, sc_c.y - 1)
	# The Reed Wall at the canyon's end: dense reeds across the way out towards the maze that
	# part (draw up and away) once the canyon heals, a shortcut; until then go round.
	var rw := b.xform_on_dir(_dir(R.call(0, 104)), 0.0, 90.0)
	lb.root_curtain("canyon", rw.translated_local(Vector3(0, -0.2, 0)), 7.0, 3.2, 5201, lb.leaf_mat)
	# More in the canyon and at its end.
	p = R.call(3, 60)
	lb.parasite(Parasite.Kind.SMALL, "canyon", p.x, p.y, 3.0)
	p = R.call(-3, 30)
	lb.mote("canyon", p.x, p.y)
	p = R.call(2, 88)
	lb.mote("canyon", p.x, p.y)
	p = R.call(-22, 130)
	lb.mote("end", p.x, p.y)
	# The Stalker Hollow: a reed-choked dell ringed by low mounds (sightlines only from their tops),
	# where a reed stalker hunts; Motes on the mounds.
	var shz: Vector2 = R.call(-40, -40)
	lb.zone("dell", shz.x, shz.y, 12)
	var dxf := func(x: float, z: float) -> Transform3D: return lb.at(shz.x, shz.y, 0.0, x, 0, z)
	for k in 5:
		var a := TAU * k / 5.0 + 0.3
		var mxf: Transform3D = dxf.call(cos(a) * 8.5, sin(a) * 8.5)
		lb.cushion(0, 0, 1.4, 1.3, mxf)
		if k % 2 == 0:
			lb.mote_xf("dell", mxf.translated_local(Vector3(0, 1.8, 0)), 0.3)
	lb.parasite_xf(Parasite.Kind.SMALL, "dell", dxf.call(-3, 2), 2.5)
	lb.parasite_xf(Parasite.Kind.MEDIUM, "dell", dxf.call(3, -3), 2.5)
	lb.mote_xf("dell", dxf.call(0, 0), 1.0)
	lb.bloom_xf(dxf.call(12, 0))

	for r in [[land.x, land.y, 20], [fz.x, fz.y, 26], [ez.x + 30, ez.y, 22], [mz.x, mz.y, 14], [shz.x, shz.y, 10]]:
		lb.food_region(r[0], r[1], r[2])
	Levels._holes(lb, 22, 401, [[_dir(cz), 34], [_dir(cv), 14], [mz_dir, 16]])
	var clear := Levels._veg_keep_clear(lb)
	# The canyon floor is a cornfield of tall reeds; crests and the far side stay open.
	var c0 := _dir(R.call(0, 22))
	var c1 := _dir(R.call(0, 96))
	var floor_ := func(dd: Vector3) -> bool: return _deg_to_arc(dd, c0, c1) < 4.0
	Vegetation.field(b, "tall", _dir(cz), 40.0, 3000, 402, {"avoid": func(dd: Vector3) -> bool: return clear.call(dd) or not floor_.call(dd),
			"clumps": 14, "fill": 0.6, "edge": 0.9})
	# The maze's reeds: dense, but a tunnel through them to the Secret Clearing stays open.
	# (The tunnel starts at the fallen log's northern end: over the log, then into the reeds.)
	var tun_a := b.up_at(log_a)
	var tun_b := _dir(sc_c)
	var in_tunnel := func(dd: Vector3) -> bool: return _deg_to_arc(dd, tun_a, tun_b) < lb.m2deg(0.9) or dd.angle_to(tun_b) < deg_to_rad(lb.m2deg(4.0))
	Vegetation.field(b, "tall", mz_dir, 26.0, 2600, 404, {"avoid": func(dd: Vector3) -> bool: return clear.call(dd) or in_tunnel.call(dd),
			"clumps": 12, "fill": 0.7, "edge": 0.8})
	Vegetation.field(b, "tall", _dir(shz), 9.0, 900, 405, {"avoid": clear, "clumps": 6, "fill": 0.7, "edge": 0.7})
	_short_cover(lb, 7000, 403, clear, func(dd: Vector3) -> bool: return _deg_to_arc(dd, c0, c1) > 12.0)


## Angle (degrees) from `dd` to the great-circle arc from `a` to `b`.
static func _deg_to_arc(dd: Vector3, a: Vector3, b: Vector3) -> float:
	var n := a.cross(b).normalized()
	var proj := (dd - n * dd.dot(n)).normalized()
	if proj.angle_to(a) + proj.angle_to(b) <= a.angle_to(b) + 0.0001:
		return rad_to_deg(asin(clampf(absf(dd.dot(n)), 0.0, 1.0)))
	return rad_to_deg(minf(dd.angle_to(a), dd.angle_to(b)))


# =========================================================================================
# 6 — CANOPY SPIRE
# =========================================================================================

static func canopy_spire(lb: LevelBuilder) -> void:
	var b := lb.ball
	var R := func(dlat: float, dlon: float) -> Vector2: return _rel(5, 2, dlat, dlon)
	b.food_weights = [0.55, 0.3, 0.15]
	b.food_target = 12
	var land: Vector2 = R.call(0, 0)
	lb.zone("landing", land.x, land.y, 30)
	var sz: Vector2 = R.call(-10, 120)
	lb.zone("spire", sz.x, sz.y, 34)
	var hz: Vector2 = R.call(30, 60)
	lb.zone("shelves", hz.x, hz.y, 30)
	var fz: Vector2 = R.call(10, -120)
	lb.zone("far", fz.x, fz.y, 40)

	var p: Vector2 = R.call(-8, 12)
	lb.bloom(p.x, p.y)
	p = R.call(14, -18)
	lb.mote("landing", p.x, p.y)
	p = R.call(-18, -8)
	lb.parasite(Parasite.Kind.SMALL, "landing", p.x, p.y, 8.0)

	# The spire: one great stem, a spiral of leaves (one plain jump each) to a crown.
	var sxf := b.xform_on_dir(_dir(sz), 0.0, 0.0)
	# A quarter turn per leaf (Expansion 6; was 72 degrees): the broad leaves stand clear of each other.
	var spiral: Array = lb.canopy_spiral(sxf, 13, 0.8, 1.0, SPIRE_TURN, 15.5, 0.9)
	var top: Transform3D = spiral[spiral.size() - 1]
	# The crown: two broad leaves out from the top of the stem.
	var crown := []
	for k in 2:
		var a := deg_to_rad(SPIRE_TURN * spiral.size() + 150.0 * k)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var cx := sxf * Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z) + PI), Vector3(dir.x, 13.4 + 0.3 * k, dir.z))
		lb.leaf_xf(cx, 3.6, 2.6)
		crown.append(cx)
	var mid5: Transform3D = spiral[5]
	lb.mote_xf("spire", mid5.translated_local(Vector3(0.6, 0.6, -2.4)), 0.4)
	var c0: Transform3D = crown[0]
	lb.mote_xf("spire", Levels.leaf_mid(c0, 2.6, 0.0).translated_local(Vector3(0, 0.6, 0)), 0.5)
	var cll := Levels._latlon(b.up_at(Levels.leaf_mid(c0, 1.8, 0.0).origin))
	lb.bloom_xf(Levels.leaf_mid(c0, 1.6, 0.0))
	var tops := []
	for xf in spiral:
		tops.append(Levels.leaf_mid(xf, 1.5, 0.0).origin + (xf as Transform3D).basis.y * 0.1)
	tops.append(Levels.leaf_mid(c0, 1.6, 0.0).origin + c0.basis.y * 0.1)
	var s0: Transform3D = spiral[0]
	var start := b.surface_point(b.up_at(Levels.leaf_mid(s0, 4.4, 0.0).origin), 0.0)
	lb.route("spire mid", start, tops.slice(0, 6), ["spire"], "spire, half way")
	lb.route("spire", start, tops, ["spire"], "canopy crown")
	# The second crown leaf, a hop across from the first (audit only: nothing to collect there).
	var c1x: Transform3D = crown[1]
	lb.bot_hints.append({"route": "crown", "audit": true, "branch": true, "start": tops[tops.size() - 1],
			"tops": [Levels.leaf_mid(c1x, 1.0, 0.0).origin + c1x.basis.y * 0.1], "zones": [], "goal": "second crown leaf"})
	p = R.call(-24, 104)
	lb.parasite(Parasite.Kind.MEDIUM, "spire", p.x, p.y, 8.0)

	# The shelves: overhanging rocks stepping up (a second, shorter climb).
	# (Half the old angular spacing: the ball doubled, the steps between the shelves did not.)
	var h0: Vector2 = R.call(24, 44)
	var h1: Vector2 = R.call(27, 50)
	var h2: Vector2 = R.call(31, 55)
	var sh0 := lb.shelf(h0.x, h0.y, 1.2, 2.0, 1.0)
	var sh1 := lb.shelf(h1.x, h1.y, 2.3, 1.9, 0.9)
	var sh2 := lb.shelf(h2.x, h2.y, 3.4, 2.1, 1.0)
	var shelf_top := func(body: Node3D) -> Vector3: return body.global_transform * Vector3(0, float(body.get_meta("top")) + 0.05, 0)
	lb.mote_xf("shelves", Transform3D(sh2.global_transform.basis, shelf_top.call(sh2) + sh2.global_transform.basis.y * 0.5), 0.5)
	var hs := b.surface_point(b.up_at(sh0.global_position + (sh0.global_position - sh1.global_position).normalized() * 3.4), 0.0)
	lb.route("shelves", hs, [shelf_top.call(sh0), shelf_top.call(sh1), shelf_top.call(sh2)], ["shelves"], "top shelf")
	p = R.call(18, 70)
	lb.parasite(Parasite.Kind.SMALL, "shelves", p.x, p.y, 8.0)
	p = R.call(34, 30)
	lb.mote("shelves", p.x, p.y)

	# The far side: a sparse slope and a lone large parasite.
	lb.hill(fz.x, fz.y, 14.0, 2.0)
	p = R.call(0, -140)
	lb.parasite(Parasite.Kind.LARGE, "far", p.x, p.y, 12.0)
	p = R.call(24, -110)
	lb.mote("far", p.x, p.y)
	p = R.call(-20, -100)
	lb.bloom(p.x, p.y)

	lb.freeze_ids()

	# ---- World expansion: Canopy Spire at radius 32 --------------------------------------------
	var kz: Vector2 = R.call(42, -62)
	lb.zone("sky", kz.x, kz.y, 22)
	# The Sky Spire: a 31 m spiral climb (a quarter turn and a metre a leaf) to a crown with the
	# whole aquarium below; a Mote halfway up; beside it the glide shaft, a wide gentle down-draft
	# he can drift down from the crown in (the safe way down; missing it is an extreme drop, which
	# never takes the last frond).
	var kxf := b.xform_on_dir(_dir(kz), 0.0, 20.0)
	var ksp: Array = lb.canopy_spiral(kxf, 30, 0.8, 1.0, SPIRE_TURN, 31.5, 1.2)
	var kcrown := []
	for k in 2:
		var a := deg_to_rad(SPIRE_TURN * ksp.size() + 150.0 * k)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var cx := kxf * Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z) + PI), Vector3(dir.x * 1.3, 30.4 + 0.3 * k, dir.z * 1.3))
		lb.leaf_xf(cx, 3.8, 2.8)
		kcrown.append(cx)
	var ktops := []
	for xf in ksp:
		ktops.append(Levels.leaf_mid(xf, 1.5, 0.0).origin + (xf as Transform3D).basis.y * 0.1)
	var kc0: Transform3D = kcrown[0]
	ktops.append(Levels.leaf_mid(kc0, 1.6, 0.0).origin + kc0.basis.y * 0.1)
	var ks0: Transform3D = ksp[0]
	var kstart := b.surface_point(b.up_at(Levels.leaf_mid(ks0, 4.4, 0.0).origin), 0.0)
	lb.route("sky spire mid", kstart, ktops.slice(0, 16), ["sky"], "the Sky Spire, half way")
	lb.route("sky spire", kstart, ktops, ["sky"], "the Sky Spire's crown")
	var k15: Transform3D = ksp[15]
	lb.mote_xf("sky", Levels.leaf_mid(k15, 1.5, 0.0).translated_local(Vector3(0, 0.6, 0)), 0.3)
	lb.mote_xf("sky", Levels.leaf_mid(kc0, 2.6, 0.0).translated_local(Vector3(0, 0.6, 0)), 0.4)
	lb.bloom_xf(Levels.leaf_mid(kc0, 1.6, 0.0))
	var shaft_dir := b.up_at(kxf * Vector3(-7.5, 0, 0))
	lb.bubble_column(shaft_dir, 2.6, 31.0, -1.6)
	lb.bot_hints.append({"glide": true, "base": b.surface_point(shaft_dir), "top": kxf * Vector3(-7.5, 30.0, 0), "radius": 2.6})
	lb.parasite(Parasite.Kind.SMALL, "sky", kz.x - 8, kz.y + 12, 4.0)
	lb.parasite(Parasite.Kind.MEDIUM, "sky", kz.x + 6, kz.y - 16, 4.0)
	lb.mote("sky", kz.x - 12, kz.y - 8)
	# More of the landing, the shelves and the far side.
	p = R.call(-30, 20)
	lb.parasite(Parasite.Kind.SMALL, "landing", p.x, p.y, 5.0)
	p = R.call(20, 16)
	lb.mote("landing", p.x, p.y)
	p = R.call(-30, -150)
	lb.mote("far", p.x, p.y)
	p = R.call(30, -150)
	lb.parasite(Parasite.Kind.SMALL, "far", p.x, p.y, 5.0)
	# The Low Garden: a sheltered hollow of mounds and coral under the spires, and a bouncy leaf
	# that throws him up onto the tallest mound (a leaf chain of three bounces).
	var lgz: Vector2 = R.call(-44, -30)
	lb.zone("garden", lgz.x, lgz.y, 14)
	var gxf := func(x: float, z: float) -> Transform3D: return lb.at(lgz.x, lgz.y, 0.0, x, 0, z)
	lb.cushion(0, 0, 1.6, 1.2, gxf.call(0, 0))
	lb.cushion(0, 0, 1.4, 2.4, gxf.call(3.4, 1.6))
	lb.cushion(0, 0, 1.3, 3.6, gxf.call(5.8, -1.2))
	var gtops := [(gxf.call(0, 0) as Transform3D) * Vector3(0, 1.2, 0), (gxf.call(3.4, 1.6) as Transform3D) * Vector3(0, 2.4, 0), (gxf.call(5.8, -1.2) as Transform3D) * Vector3(0, 3.6, 0)]
	lb.route("garden mounds", (gxf.call(-3.2, 0) as Transform3D).origin, gtops, ["garden"], "the tallest mound")
	var gtop: Vector3 = gtops[2]
	lb.mote_xf("garden", Transform3D(MossBall.frame_at(b.up_at(gtop), 0.0), gtop + b.up_at(gtop) * 0.5), 0.3)
	lb.parasite_xf(Parasite.Kind.SMALL, "garden", gxf.call(-5, 6), 3.0)
	lb.parasite_xf(Parasite.Kind.SMALL, "garden", gxf.call(6, 8), 3.0)
	lb.mote_xf("garden", gxf.call(-6, -6), 1.2)
	lb.mote_xf("garden", gxf.call(8, 4), 1.2)
	lb.bloom_xf(gxf.call(-8, 2))

	for r in [[land.x, land.y, 24], [fz.x, fz.y, 26], [kz.x, kz.y, 16], [lgz.x, lgz.y, 10]]:
		lb.food_region(r[0], r[1], r[2])
	Levels._holes(lb, 16, 501, [[_dir(sz), 16], [_dir(hz), 14], [_dir(kz), 14]])
	# Sparse ground cover, a stand of medium growth round the spire's foot, tall reeds far off.
	var clear := Levels._veg_keep_clear(lb, [[_dir(sz), 5.0], [_dir(kz), 6.0], [shaft_dir, 6.0]])
	_short_cover(lb, 3600, 511, clear, Levels._stands(512, 0.0))
	Vegetation.field(b, "medium", _dir(sz), 16.0, 700, 513, {"avoid": clear, "clumps": 8})
	Vegetation.field(b, "tall", _dir(fz), 18.0, 900, 514, {"avoid": clear, "clumps": 8})
	Vegetation.field(b, "medium", _dir(kz), 14.0, 500, 515, {"avoid": clear, "clumps": 6})


# =========================================================================================
# 7 — HOLLOW GROTTO
# =========================================================================================

static func hollow_grotto(lb: LevelBuilder) -> void:
	var b := lb.ball
	var R := func(dlat: float, dlon: float) -> Vector2: return _rel(6, 3, dlat, dlon)
	b.food_weights = [0.5, 0.2, 0.3]
	b.food_target = 13
	var land: Vector2 = R.call(0, 0)
	# World expansion (radius 22 -> 44): the Undercut Ravine in a basalt upland (registered before
	# anything stands on the ground).
	var uz: Vector2 = R.call(-44, 30)
	var uz_dir := _dir(uz)
	b.add_plateau(uz_dir, lb.m2deg(20.0) * PI / 180.0, 3.2, 8.0)
	var uzp := func(x: float, z: float) -> Vector3: return lb.at(uz.x, uz.y, 0.0, x, 0, z).origin
	var ull := func(x: float, z: float) -> Vector2: return Levels._latlon(b.up_at(uzp.call(x, z)))
	lb.ravine([ull.call(-9, 1), ull.call(-3, -1), ull.call(3, 1), ull.call(9, -1)], 3.4, 3.2, 1.2, "b7.undercut")
	lb.zone("landing", land.x, land.y, 26)
	var gz: Vector2 = R.call(-20, 92)
	lb.zone("grotto", gz.x, gz.y, 28)
	var kz: Vector2 = R.call(30, -64)
	lb.zone("cavelet", kz.x, kz.y, 24)
	var vz: Vector2 = R.call(8, 42)
	lb.zone("corridors", vz.x, vz.y, 30)
	var fz: Vector2 = R.call(-10, -150)
	lb.zone("far", fz.x, fz.y, 40)

	var p: Vector2 = R.call(-7, 10)
	lb.bloom(p.x, p.y)
	p = R.call(10, -14)
	lb.mote("landing", p.x, p.y)
	p = R.call(-16, -16)
	lb.parasite(Parasite.Kind.SMALL, "landing", p.x, p.y, 8.0)

	# A sheltering shelf by the landing, and a high one beside the low ridge (one step up from its
	# crest).
	var sh0p: Vector2 = R.call(16, 18)
	lb.shelf(sh0p.x, sh0p.y, 1.6, 2.2, 1.1)
	# (Its step from the ridge's crest kept in metres on the bigger ball.)
	var sh1p: Vector2 = R.call(-3, 50)
	var sh1 := lb.shelf(sh1p.x, sh1p.y, 2.75, 2.2, 1.1)

	# Two low ridges with a vegetation corridor between them (exposed rock on the crests).
	var r0a: Vector2 = R.call(0, 30)
	var r0b: Vector2 = R.call(4, 66)
	var r1a: Vector2 = R.call(16, 28)
	var r1b: Vector2 = R.call(20, 64)
	var ra := lb.ridge(r0a.x, r0a.y, r0b.x, r0b.y, 1.7, 5.0, 1.6, 61)
	lb.ridge(r1a.x, r1a.y, r1b.x, r1b.y, 1.5, 5.0, 1.5, 62)
	var rac: Array = ra.get_meta("crest")
	var shelf_top := func(body: Node3D) -> Vector3: return body.global_transform * Vector3(0, float(body.get_meta("top")) + 0.05, 0)
	lb.mote_xf("corridors", Transform3D(sh1.global_transform.basis, shelf_top.call(sh1) + sh1.global_transform.basis.y * 0.5), 0.5)
	# Along the crest to the point nearest the shelf, then up onto it.
	var near_i := 0
	for i in rac.size():
		if (rac[i] as Vector3).distance_to(sh1.global_position) < (rac[near_i] as Vector3).distance_to(sh1.global_position):
			near_i = i
	# (Landing on the shelf's near side, then walking to its middle.)
	var st1: Vector3 = shelf_top.call(sh1)
	var toward: Vector3 = (rac[near_i] as Vector3) - st1
	toward -= b.up_at(st1) * toward.dot(b.up_at(st1))
	lb.route("high shelf", rac[0], rac.slice(1, near_i, 3) + [rac[near_i], st1 + toward.normalized() * 1.4, st1], ["corridors"], "high shelf")
	p = R.call(9, 46)
	lb.mote("corridors", p.x, p.y)
	p = R.call(8, 56)
	lb.parasite(Parasite.Kind.MEDIUM, "corridors", p.x, p.y, 6.0)

	# The grotto: a big cave with a pearl.
	lb.cave(gz.x, gz.y, 200.0, 8.0, "pearl")
	p = R.call(-2, 100)
	lb.parasite(Parasite.Kind.SMALL, "grotto", p.x, p.y, 8.0)
	p = R.call(-34, 80)
	lb.mote("grotto", p.x, p.y)

	# The cavelet: a smaller grotto with its own pearl.
	lb.cave(kz.x, kz.y, 40.0, 6.6, "pearl")
	p = R.call(22, -84)
	lb.mote("cavelet", p.x, p.y)
	p = R.call(40, -44)
	lb.parasite(Parasite.Kind.SMALL, "cavelet", p.x, p.y, 8.0)
	p = R.call(14, -38)
	lb.bloom(p.x, p.y)

	# The far side: a large parasite in the open.
	lb.hill(fz.x + 12, fz.y, 16.0, 2.2)
	p = R.call(-14, -140)
	lb.parasite(Parasite.Kind.LARGE, "far", p.x, p.y, 12.0)
	p = R.call(6, -164)
	lb.mote("far", p.x, p.y)
	p = R.call(-30, -120)
	lb.bloom(p.x, p.y)

	lb.freeze_ids()

	# ---- World expansion: Hollow Grotto at radius 44 -------------------------------------------
	var cz: Vector2 = R.call(34, 150)
	lb.zone("chamber", cz.x, cz.y, 14)
	lb.zone("undercut", uz.x, uz.y, 18)
	var shz: Vector2 = R.call(-10, -60)
	lb.zone("shaft", shz.x, shz.y, 12)
	# The Glow Chamber: the biggest grotto, glow-worms in the dark and a pearl on its high ledge.
	# A boulder seals its door until the grotto heals (a restored opening).
	var n_hints := lb.bot_hints.size()
	lb.cave(cz.x, cz.y, 120.0, 10.0, "pearl")
	var ch: Dictionary = {}
	for i in range(n_hints, lb.bot_hints.size()):
		if lb.bot_hints[i].has("cave"):
			ch = lb.bot_hints[i]
	var door: Vector3 = ch["door"]
	var entry: Vector3 = ch["entry"]
	var boulder := RestorationGate.new()
	var bxf := Transform3D(MossBall.frame_at(b.up_at(door), 0.0), door.lerp(entry, 0.35) + b.up_at(door) * 0.9)
	var bsh := CollisionShape3D.new()
	var bsp := SphereShape3D.new()
	bsp.radius = 1.6
	bsh.shape = bsp
	boulder.add_child(bsh)
	var bmi := MeshInstance3D.new()
	var bsm := SphereMesh.new()
	bsm.radius = 1.6
	bsm.height = 3.0
	bmi.mesh = bsm
	bmi.material_override = lb.shell_mat
	boulder.add_child(bmi)
	boulder.setup(b, "grotto", "retract", bxf, bxf.translated_local(Vector3(0, -2.6, 0)), 2.5)
	boulder.set_meta("floats_by_design", "a boulder sealing a cave door")
	lb.root.add_child(boulder)
	lb.bot_hints.append({"hollow": true, "door": entry, "inside": ch["centre"], "zone": "chamber", "gate": boulder})
	var chc: Vector3 = ch["centre"]
	var chup := b.up_at(chc)
	lb.mote_xf("chamber", Transform3D(MossBall.frame_at(chup, 0.0), chc + MossBall.frame_at(chup, 0.0).x * 5.0), 0.6)
	lb.mote_xf("chamber", Transform3D(MossBall.frame_at(chup, 0.0), chc - MossBall.frame_at(chup, 0.0).x * 5.0), 0.6)
	lb.parasite(Parasite.Kind.SMALL, "chamber", cz.x - 14, cz.y + 6, 4.0)
	# The Undercut Ravine: through a basalt upland, crossed on arched stone bridges (or round).
	for bx in [-5.5, 5.5]:
		var ba := b.surface_point(b.up_at(uzp.call(bx, -5.4)))
		var bb := b.surface_point(b.up_at(uzp.call(bx, 5.4)))
		var ubr := lb.bridge(ba, bb, 1.0, 1.9, 0.8)
		var ubl: Array = ubr.get_meta("top_line")
		lb.crossings.append({"a": ba, "b": bb, "gate": null})
		lb.bot_hints.append({"route": "undercut bridge %d" % int(bx), "audit": true, "start": ba, "tops": [ubl[5], ubl[10], ubl[15], bb], "zones": [], "goal": "across the Undercut"})
	var uxf := func(x: float, z: float) -> Transform3D: return lb.at(uz.x, uz.y, 0.0, x, 0, z)
	lb.parasite_xf(Parasite.Kind.SMALL, "undercut", uxf.call(-6, -9), 3.0)
	lb.parasite_xf(Parasite.Kind.MEDIUM, "undercut", uxf.call(6, 9), 3.0)
	lb.parasite_xf(Parasite.Kind.SMALL, "undercut", uxf.call(13, 0), 3.0)
	lb.mote_xf("undercut", uxf.call(0, -8), 1.0)
	lb.mote_xf("undercut", uxf.call(-2, 9), 1.0)
	lb.mote_xf("undercut", uxf.call(-13, 0), 1.0)
	lb.bloom_xf(uxf.call(8, -10))
	# The Shaft: a tall basalt chimney; a bubble column rises beside it to its ledge.
	var shaft := lb.shelf(shz.x, shz.y, 6.0, 2.4, 1.3)
	var sfr := MossBall.frame_at(b.up_at(shaft.global_position), 0.0)
	var scol := b.up_at(shaft.global_position + sfr.x * 5.2)
	lb.bubble_column(scol, 0.9, 7.4, 5.5)
	var stop := shaft.global_position + b.up_at(shaft.global_position) * 6.0
	var sedge := shaft.global_position + sfr.x * 1.8 + b.up_at(shaft.global_position) * 6.0
	lb.bot_hints.append({"route": "shaft column", "lift": true, "start": b.surface_point(scol), "tops": [b.surface_point(scol, 7.0), sedge, stop], "zones": ["shaft"], "goal": "the Shaft's ledge"})
	lb.mote_xf("shaft", Transform3D(sfr, stop + b.up_at(stop) * 0.5), 0.4)
	lb.parasite(Parasite.Kind.SMALL, "shaft", shz.x + 6, shz.y + 8, 4.0)
	lb.mote("shaft", shz.x - 8, shz.y - 6)
	# More of the landing and the far side.
	p = R.call(-24, 12)
	lb.mote("landing", p.x, p.y)
	p = R.call(10, -150)
	lb.parasite(Parasite.Kind.SMALL, "far", p.x, p.y, 5.0)
	p = R.call(-30, -170)
	lb.mote("far", p.x, p.y)
	# The Basalt Columns: a field of hexagonal-ish stone columns stepping up in a spiral to a high
	# one with a Mote (another way up in this world of shafts).
	var bcz: Vector2 = R.call(22, -118)
	lb.zone("columns", bcz.x, bcz.y, 12)
	var colxf := func(x: float, z: float) -> Transform3D: return lb.at(bcz.x, bcz.y, 0.0, x, 0, z)
	var bctops := []
	for k in 5:
		var a := 1.2 * k
		var bh := 1.1 + 1.1 * k
		var bd := b.up_at((colxf.call(cos(a) * 2.6, sin(a) * 2.6) as Transform3D).origin)
		lb.stone_column(bd, 0.95, bh)
		bctops.append(b.surface_point(bd, bh))
	lb.route("basalt columns", (colxf.call(5.4, 0) as Transform3D).origin, bctops, ["columns"], "the highest column")
	var bct: Vector3 = bctops[4]
	lb.mote_xf("columns", Transform3D(MossBall.frame_at(b.up_at(bct), 0.0), bct + b.up_at(bct) * 0.5), 0.3)
	lb.parasite_xf(Parasite.Kind.SMALL, "columns", colxf.call(-6, 5), 3.0)
	lb.parasite_xf(Parasite.Kind.MEDIUM, "columns", colxf.call(7, -5), 3.0)
	lb.mote_xf("columns", colxf.call(-7, -4), 1.0)
	lb.mote_xf("columns", colxf.call(6, 6), 1.0)
	lb.bloom_xf(colxf.call(9, 0))

	for r in [[land.x, land.y, 22], [fz.x, fz.y, 26], [vz.x, vz.y, 16], [uz.x, uz.y, 14], [shz.x, shz.y, 12], [bcz.x, bcz.y, 10]]:
		lb.food_region(r[0], r[1], r[2])
	Levels._holes(lb, 18, 601, [[_dir(gz), 16], [_dir(kz), 13], [_dir(vz), 22], [_dir(cz), 18], [uz_dir, 14], [_dir(shz), 10]])
	var clear := Levels._veg_keep_clear(lb, [[_dir(cz), 16.0], [_dir(shz), 8.0]])
	# A medium corridor between the low ridges; sparse cover elsewhere (bare basalt shows).
	Vegetation.corridor(b, "medium", _dir(R.call(8, 28)), _dir(R.call(12, 66)), 6.0, 900, 611, {"avoid": clear})
	_short_cover(lb, 4800, 612, clear, Levels._stands(613, -0.1))
	Vegetation.field(b, "tall", _dir(R.call(-40, 150)), 14.0, 900, 614, {"avoid": clear, "clumps": 8})
