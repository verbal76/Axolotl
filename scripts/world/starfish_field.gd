class_name StarfishField
extends Node
## The red starfish in the world (docs/SKILL_TREE.md): once the world has settled (its Motes,
## blooms and rewards placed), every starfish not yet collected is put on its authored spot
## (StarfishTable), checked with Treasure Hunt's validators and, if a spot no longer holds, moved to
## the nearest valid point on the same feature (Starfish.resolve). Then, each physics frame, his
## body touching one collects it: no button, on the ground or in the air.

var g: Game
var stars: Array[Starfish] = []
var placed := false
## Per id: "authored", "relocated" or "invalid" (and where), for Diagnostics and tests.
var report := {}
var _frames := 0


func _ready() -> void:
	process_physics_priority = 5


func _physics_process(_dt: float) -> void:
	if g == null or g.gill == null or g.player == null:
		return
	if not placed:
		# (After the Motes' and rewards' first frames, so their anchors are known.)
		_frames += 1
		for b in g.balls:
			for bl in b.blooms:
				if not bl.is_placed():
					return
		if _frames >= 3:
			place_all()
		return
	var p := g.player
	if p.state != "normal" or not p.controls_enabled or g.cinematic != "" or g.state != "play":
		return
	var c := p.body_center()
	for s in stars:
		if s.collected or s.ball != p.ball:
			continue
		if c.distance_to(s.pick_point()) < Starfish.REACH:
			collect(s)


## Places every starfish not yet collected (once).
func place_all() -> void:
	placed = true
	var keep := {}
	for e in StarfishTable.STARS:
		var id: String = e["id"]
		if g.gill.has_star(id):
			report[id] = "collected"
			continue
		var b: MossBall = g.balls[int(e["ball"]) - 1]
		if not keep.has(b):
			keep[b] = Starfish.keep_clear_points(b)
		var r := Starfish.resolve(b, e, keep[b])
		var s := Starfish.new()
		s.setup(b, id, r["pos"])
		s.relocated = r["relocated"]
		# (Under this node, not the ball: nothing that walks a ball's children meets them.)
		add_child(s)
		stars.append(s)
		report[id] = ("relocated" if r["relocated"] else "authored") if r["valid"] else "invalid"
		if r["relocated"] or not r["valid"]:
			print("[STARFISH] %s %s at %s" % [id, report[id], str((r["pos"] as Vector3).snapped(Vector3.ONE * 0.01))])


func collect(s: Starfish) -> void:
	if s.collected:
		return
	g.gill.collect(s.id)
	s.collect_fx()
	Sfx.play("starfish", s.pick_point())
	Settings.haptic("mote")
	g.hud.star_collected(g.gill.stars(), StarfishTable.COUNT, g.gill.balance())
	stars.erase(s)


func find(id: String) -> Starfish:
	for s in stars:
		if s.id == id:
			return s
	return null


func diagnostics_text() -> String:
	var counts := {}
	for id in report:
		counts[report[id]] = int(counts.get(report[id], 0)) + 1
	return "  Starfish in the world: %d; %s" % [stars.size(), str(counts)]
