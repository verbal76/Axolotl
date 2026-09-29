class_name TreasurePlay
extends Node
## Treasure Hunt in play (docs/TREASURE_HUNT.md): only the current object exists in the world; he
## collects it by lunging into it (nothing else can: it is never a strike target, and only
## Game.lunge_contact asks); the find is saved at once, before the celebration (confetti, a
## couple of small fireworks and his happy dance), so quitting at any moment neither loses it nor
## counts it twice; then the next object appears. After the fourteenth: a short finale and the
## choice of a new hunt (smaller treasures from the second hunt on).
##
## Built lazily: nothing here costs startup (models, placements and the icon are made when a hunt
## is played), and none of it touches completion, the run clock or any generator but the hunt's.

const DANCE_S := 2.8
const FINALE_S := 3.6
## Extra reach for the lunge beyond the object's own size (phones: forgiving, never pixel-exact).
const REACH := 0.55
## Lunge aim help toward the current object (like food): range and cone.
const AIM_RANGE := 3.6
const AIM_CONE := deg_to_rad(55.0)
const CONFETTI := [Color(1.0, 0.35, 0.35), Color(1.0, 0.85, 0.2), Color(0.35, 0.8, 1.0), Color(0.55, 1.0, 0.45), Color(1.0, 0.5, 0.95)]

var g: Game
var panel: TreasurePanel
var node: Node3D
var node_index := -1
var celebrating := false
## The last find, for tests and diagnostics: {index, kind, at, final}.
var last := {}
## The nearest a lunge came to the current object without collecting it (m beyond reach; tests).
var near_miss := INF
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "TreasurePlay"
	_rng.seed = 0x7ea5


func st() -> Dictionary:
	return TreasureHunt.state_of(g.run_save.run())


func eligible() -> bool:
	return g != null and g.run_save != null and TreasureHunt.eligible(g.completion_percent())


## The hunt is on (a current object to find, shown and collectible in play).
func hunting() -> bool:
	return eligible() and bool(st()["active"]) and TreasureHunt.has_hunt(st()) and not TreasureHunt.is_complete(st())


## Starts (or resumes) the hunt from a menu. A finished hunt, or none yet, begins a new one.
func start() -> void:
	if not eligible():
		return
	var s := st()
	var fresh := not TreasureHunt.has_hunt(s) or TreasureHunt.is_complete(s)
	if fresh:
		TreasureHunt.begin_hunt(s, g.balls)
	s["active"] = true
	g.save_run()
	_ensure_panel()
	panel.show_message("NEW TREASURE HUNT" if fresh else "TREASURE HUNT",
			"The treasures are smaller this time." if fresh and int(s["hunt"]) == 2 else "")
	refresh()


## Puts the hunt away (progress kept; the object is no longer shown until it is resumed).
func stop() -> void:
	st()["active"] = false
	g.save_run()
	refresh()


## Brings the world and the panel in line with the state (called on play, and after any change).
func refresh() -> void:
	var want := hunting() and not celebrating
	if want:
		var idx := int(st()["index"])
		if node == null or node_index != idx:
			_despawn()
			_spawn(idx)
	elif not celebrating:
		_despawn()
	if panel:
		panel.set_target(TreasureHunt.current(st()) if hunting() else {}, int(st()["index"]))


func _process(_dt: float) -> void:
	if g == null:
		return
	# In play only (not the title, the pause menu or the aquarium experiences).
	var show := g.state == "play"
	if node:
		node.visible = show
	if panel:
		panel.visible = show and (hunting() or celebrating or panel.busy())


func _ensure_panel() -> void:
	if panel == null:
		panel = TreasurePanel.new()
		panel.tp = self
		g.add_child(panel)


func _spawn(idx: int) -> void:
	_ensure_panel()
	var s := st()
	var t: Dictionary = (s["targets"] as Array)[idx]
	var b: MossBall = g.balls[int(t["world"])]
	var scale := float(t.get("scale", 1.0))
	# A saved spot that is no longer good (the world changed, or damage): a new spot in the same
	# world for the same object; the order and the progress stay.
	if not TreasureHunt.target_ok(b, t):
		TreasureHunt.recover(s, idx, g.balls)
		g.save_run()
	var pos := TreasureHunt.target_pos(t)
	node = TreasureModels.node(t["kind"], scale)
	node.set_meta("treasure_index", idx)
	b.add_child(node)
	var up := b.up_at(pos)
	var fr := MossBall.frame_at(up, float(t.get("yaw", 0.0)))
	node.global_transform = Transform3D(Basis(fr.x, up, fr.z), pos - up * 0.02).scaled_local(node.scale)
	node_index = idx


func _despawn() -> void:
	if node:
		node.queue_free()
	node = null
	node_index = -1


## Where he would lunge to (its middle), for the aim help and the reach test.
func target_center() -> Vector3:
	if node == null:
		return Vector3.INF
	var t: Dictionary = TreasureHunt.current(st())
	var h := TreasureModels.height_of(t["kind"], float(t.get("scale", 1.0)))
	return node.global_position + node.global_basis.y.normalized() * h * 0.45


func reach() -> float:
	var t: Dictionary = TreasureHunt.current(st())
	if t.is_empty():
		return 0.0
	return TreasureModels.size_of(t["kind"], float(t.get("scale", 1.0))) * 0.4 + REACH


## Lunge aim help: the current object's middle when it is ahead and near, else INF.
func aim(p: Axolotl, dir: Vector3) -> Vector3:
	if not hunting() or celebrating or node == null or p.ball != g.balls[node_index_world()]:
		return Vector3.INF
	var c := target_center()
	var d := c - p.body_center()
	var flat := d - p.up * d.dot(p.up)
	if flat.length() > AIM_RANGE or absf(d.dot(p.up)) > 1.5 or (flat.length() > 0.3 and dir.angle_to(flat) > AIM_CONE):
		return Vector3.INF
	return c


func node_index_world() -> int:
	return int((st()["targets"] as Array)[node_index]["world"]) if node_index >= 0 else -1


## Called by Game.lunge_contact while he lunges (and only then): the mouth's sweep from chest to
## snout tip meets the current object. Returns true if it was collected.
func try_collect(p: Axolotl, chest: Vector3, tip: Vector3) -> bool:
	if not hunting() or celebrating or node == null or p.ball != g.balls[node_index_world()]:
		return false
	var c := target_center()
	var d := seg_dist(c, chest, tip)
	if d > reach():
		near_miss = minf(near_miss, d - reach())
		return false
	_collect(p, c)
	return true


static func seg_dist(pt: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var k := clampf((pt - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return pt.distance_to(a + ab * k)


func _collect(p: Axolotl, at: Vector3) -> void:
	var s := st()
	var idx := int(s["index"])
	var kind: String = (s["targets"] as Array)[idx]["kind"]
	if not TreasureHunt.collect(s, idx):
		return
	var final := TreasureHunt.is_complete(s)
	# Saved before anything is shown: a quit mid-celebration keeps the find, exactly once.
	g.save_run()
	last = {"index": idx, "kind": kind, "at": at, "final": final}
	celebrating = true
	_despawn()
	Sfx.play("discover", at, -2.0)
	Settings.haptic("heavy")
	_celebrate(p, at, final)


func _celebrate(p: Axolotl, at: Vector3, final: bool) -> void:
	var up := p.ball.up_at(at)
	# Confetti: a puff of colours where it was (the pooled water effects: bounded, self-clearing).
	for c in CONFETTI:
		WaterFX.inst.sparkle(at, c, 14 if not final else 18, 2.8, 0.13, 1.6)
	_firework(at + up * 0.3, up, 0.0)
	_firework(at + up * 0.3 + p.facing.cross(up) * 0.8, up, 0.35)
	if final:
		for k in 3:
			_firework(at + up * 0.3 + MossBall.frame_at(up, k * 120.0).z * 1.4, up, 0.7 + k * 0.3)
	_ensure_panel()
	panel.set_target({}, int(st()["index"]))
	panel.show_found(TreasureHunt.kind_name(str(last["kind"])), int(st()["index"]), final)
	# His happy dance, once he is on the ground (a lunge can end a hair above it).
	if g.t2 != null:
		g.t2.cancel()
	var t0 := Time.get_ticks_msec()
	while not p.grounded and Time.get_ticks_msec() - t0 < 500 and is_inside_tree():
		await get_tree().physics_frame
	if p.state == "normal":
		p.state = "celebrate"
		p.controls_enabled = false
		p.velocity = Vector3.ZERO
		p.lunge_t = -1.0
		p.model.lunge_t = -1.0
		p.invuln_t = maxf(p.invuln_t, DANCE_S + 0.5)
		p.model.start_dance()
	await get_tree().create_timer(DANCE_S, false).timeout
	if p.state == "celebrate":
		p.state = "normal"
		p.controls_enabled = g.state == "play"
	if final:
		await get_tree().create_timer(maxf(0.0, FINALE_S - DANCE_S), false).timeout
		celebrating = false
		panel.show_complete(int(st()["hunt"]) == 1)
	else:
		celebrating = false
	refresh()


## A small firework: a spark rising a couple of metres, then a burst (pooled effects; nothing is left).
func _firework(from: Vector3, up: Vector3, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	var col: Color = CONFETTI[_rng.randi() % CONFETTI.size()]
	var rise := 2.2 + _rng.randf() * 0.8
	WaterFX.inst._spawn_puff(from, up * rise / 0.55, 0.55, 0.15, Color(1.0, 0.95, 0.8, 0.95), 0.0)
	await get_tree().create_timer(0.55, false).timeout
	WaterFX.inst.sparkle(from + up * rise, col, 26, 3.2, 0.12, 1.1)
	WaterFX.inst.sparkle(from + up * rise, Color(1.0, 1.0, 0.9, 0.9), 8, 1.4, 0.09, 0.6)
