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
	b.food_target = 6
	var land: Vector2 = R.call(0, 0)
	lb.hill(land.x + 30, land.y + 150, 7.0, 1.4)
	lb.hill(land.x - 60, land.y + 120, 6.0, 1.2)

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
	lb.route("terraces", tp.call(9.5, 0.0), [tp.call(5.8, 1.25), tp.call(2.6, 2.45), tp.call(0.4, 3.65)], ["terraces"], "terrace crown")
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
	lb.mote("arch", ll.x, ll.y + 3.0, -1.4, 1.0)   # beneath it (its search starts under the slab)
	lb.mote_xf("arch", Transform3D(MossBall.frame_at(b.up_at(mid), 0.0), mid + b.up_at(mid) * 0.5), 0.5)
	var a_start: Vector3 = b.surface_point(b.up_at(line[0]), 0.0) - (line[3] - line[0]).normalized() * 1.2
	lb.route("arch", b.surface_point(b.up_at(a_start), 0.0), [line[4], line[9], line[line.size() / 2]], ["arch"], "arch top")
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
	lb.parasite(Parasite.Kind.MEDIUM, "far", p.x, p.y, 10.0)
	p = R.call(20, -150)
	lb.mote("far", p.x, p.y)
	p = R.call(30, 140)
	lb.bloom(p.x, p.y)

	for r in [[land.x, land.y, 30], [tz.x + 20, tz.y + 30, 25], [fz.x, fz.y, 35]]:
		lb.food_region(r[0], r[1], r[2])
	Levels._holes(lb, 8, 301, [[_dir(tz), 18], [_dir(cv), 14], [_dir(az), 14]])
	# Open, low growth: sunny and readable; a few medium clumps.
	var clear := Levels._veg_keep_clear(lb)
	_short_cover(lb, 1800, 311, clear)
	Vegetation.field(b, "medium", _dir(R.call(-28, 130)), 12.0, 260, 312, {"avoid": clear, "clumps": 4})


# =========================================================================================
# 5 — REED CANYON
# =========================================================================================

static func reed_canyon(lb: LevelBuilder) -> void:
	var b := lb.ball
	var R := func(dlat: float, dlon: float) -> Vector2: return _rel(4, 1, dlat, dlon)
	b.food_weights = [0.45, 0.3, 0.25]
	b.food_target = 7
	var land: Vector2 = R.call(0, 0)
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
	var n0: Vector2 = R.call(14, 22)
	var n1: Vector2 = R.call(14, 96)
	var s0: Vector2 = R.call(-14, 22)
	var s1: Vector2 = R.call(-14, 96)
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
	lb.hill(fz.x + 10, fz.y, 9.0, 1.8)
	lb.hill(fz.x - 25, fz.y + 30, 8.0, 1.5)
	p = R.call(20, -140)
	lb.mote("far", p.x, p.y)
	p = R.call(-4, -120)
	lb.parasite(Parasite.Kind.MEDIUM, "far", p.x, p.y, 10.0)
	p = R.call(-20, -150)
	lb.bloom(p.x, p.y)

	for r in [[land.x, land.y, 25], [fz.x, fz.y, 40], [ez.x + 30, ez.y, 30]]:
		lb.food_region(r[0], r[1], r[2])
	Levels._holes(lb, 8, 401, [[_dir(cz), 34], [_dir(cv), 14]])
	var clear := Levels._veg_keep_clear(lb)
	# The canyon floor is a cornfield of tall reeds; crests and the far side stay open.
	var c0 := _dir(R.call(0, 22))
	var c1 := _dir(R.call(0, 96))
	var floor_ := func(dd: Vector3) -> bool: return _deg_to_arc(dd, c0, c1) < 6.0
	Vegetation.field(b, "tall", _dir(cz), 40.0, 1500, 402, {"avoid": func(dd: Vector3) -> bool: return clear.call(dd) or not floor_.call(dd),
			"clumps": 10, "fill": 0.6, "edge": 0.9})
	_short_cover(lb, 2200, 403, clear, func(dd: Vector3) -> bool: return _deg_to_arc(dd, c0, c1) > 20.0)


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
	b.food_target = 5
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
	var spiral: Array = lb.canopy_spiral(sxf, 13, 0.8, 1.0, 72.0, 15.5, 0.9)
	var top: Transform3D = spiral[spiral.size() - 1]
	# The crown: two broad leaves out from the top of the stem.
	var crown := []
	for k in 2:
		var a := deg_to_rad(72.0 * spiral.size() + 150.0 * k)
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
		tops.append(Levels.leaf_mid(xf, 2.0, 0.0).origin + (xf as Transform3D).basis.y * 0.1)
	tops.append(Levels.leaf_mid(c0, 1.6, 0.0).origin + c0.basis.y * 0.1)
	var s0: Transform3D = spiral[0]
	var start := b.surface_point(b.up_at(Levels.leaf_mid(s0, 3.6, 0.0).origin), 0.0)
	lb.route("spire mid", start, tops.slice(0, 6), ["spire"], "spire, half way")
	lb.route("spire", start, tops, ["spire"], "canopy crown")
	# The second crown leaf, a hop across from the first (audit only: nothing to collect there).
	var c1x: Transform3D = crown[1]
	lb.bot_hints.append({"route": "crown", "audit": true, "branch": true, "start": tops[tops.size() - 1],
			"tops": [Levels.leaf_mid(c1x, 1.0, 0.0).origin + c1x.basis.y * 0.1], "zones": [], "goal": "second crown leaf"})
	p = R.call(-24, 104)
	lb.parasite(Parasite.Kind.MEDIUM, "spire", p.x, p.y, 8.0)

	# The shelves: overhanging rocks stepping up (a second, shorter climb).
	var h0: Vector2 = R.call(24, 44)
	var h1: Vector2 = R.call(30, 56)
	var h2: Vector2 = R.call(38, 66)
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
	lb.hill(fz.x, fz.y, 7.0, 1.4)
	p = R.call(0, -140)
	lb.parasite(Parasite.Kind.LARGE, "far", p.x, p.y, 12.0)
	p = R.call(24, -110)
	lb.mote("far", p.x, p.y)
	p = R.call(-20, -100)
	lb.bloom(p.x, p.y)

	for r in [[land.x, land.y, 30], [fz.x, fz.y, 40]]:
		lb.food_region(r[0], r[1], r[2])
	Levels._holes(lb, 6, 501, [[_dir(sz), 16], [_dir(hz), 14]])
	# Sparse ground cover, a stand of medium growth round the spire's foot, tall reeds far off.
	var clear := Levels._veg_keep_clear(lb, [[_dir(sz), 5.0]])
	_short_cover(lb, 900, 511, clear, Levels._stands(512, 0.0))
	Vegetation.field(b, "medium", _dir(sz), 16.0, 300, 513, {"avoid": clear, "clumps": 5})
	Vegetation.field(b, "tall", _dir(fz), 18.0, 380, 514, {"avoid": clear, "clumps": 4})


# =========================================================================================
# 7 — HOLLOW GROTTO
# =========================================================================================

static func hollow_grotto(lb: LevelBuilder) -> void:
	var b := lb.ball
	var R := func(dlat: float, dlon: float) -> Vector2: return _rel(6, 3, dlat, dlon)
	b.food_weights = [0.5, 0.2, 0.3]
	b.food_target = 6
	var land: Vector2 = R.call(0, 0)
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
	var sh1p: Vector2 = R.call(-8, 50)
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
	lb.hill(fz.x + 12, fz.y, 8.0, 1.6)
	p = R.call(-14, -140)
	lb.parasite(Parasite.Kind.LARGE, "far", p.x, p.y, 12.0)
	p = R.call(6, -164)
	lb.mote("far", p.x, p.y)
	p = R.call(-30, -120)
	lb.bloom(p.x, p.y)

	for r in [[land.x, land.y, 28], [fz.x, fz.y, 40], [vz.x, vz.y, 20]]:
		lb.food_region(r[0], r[1], r[2])
	Levels._holes(lb, 7, 601, [[_dir(gz), 16], [_dir(kz), 13], [_dir(vz), 22]])
	var clear := Levels._veg_keep_clear(lb)
	# A medium corridor between the low ridges; sparse cover elsewhere (bare basalt shows).
	Vegetation.corridor(b, "medium", _dir(R.call(8, 28)), _dir(R.call(12, 66)), 9.0, 420, 611, {"avoid": clear})
	_short_cover(lb, 1300, 612, clear, Levels._stands(613, -0.1))
	Vegetation.field(b, "tall", _dir(R.call(-40, 150)), 14.0, 360, 614, {"avoid": clear, "clumps": 4})
