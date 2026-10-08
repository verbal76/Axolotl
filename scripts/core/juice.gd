class_name Juice
extends Node
## Mote v107 game feel (owner, 2026-10-08; docs/JUICE.md): presentation that OBSERVES play and
## RESPONDS with sound, haptics, puffs and Gill's body, and never drives it.
##
## The rules this keeps (the owner's, after the read-only audit):
## - Nothing here moves, times, damages, heals, targets, saves or decides anything. Turning it all
##   off (`enabled = false`) changes no outcome: the unit tests prove play is identical either way.
## - No WaterFX.impulse(): it moves food, Motes and parasites. Only puffs (WaterFX.silt_kick,
##   touch_ring, sparkle, wisp), the cosmetic wake, sounds, haptics and the model's poses.
## - Cosmetic randomness only from _fx_rng (never the gameplay sequence).
## - Event-driven; the few things read every frame (his invulnerability, starts and stops, the
##   edge assist's counter, steps) are a handful of comparisons. Emission is timed, never per frame.
## - Small: 3-12 optional puffs an event, dropped first when the puff pool is busy.

static var enabled := true
static var inst: Juice
static var _fx_rng := RandomNumberGenerator.new()

const PEARL := Color(1.0, 0.55, 0.38, 0.95)
const UPGRADE := Color(0.4, 1.0, 0.9, 1.0)
## Starts and stops: a real change of pace on the ground, then a cool-down (no spam from jitter).
const START_FROM := 0.6
const START_TO := 3.4
const STOP_FROM := 3.6
const STOP_TO := 0.7
const PACE_WINDOW := 0.3
const SCUFF_COOLDOWN := 0.7
## Moss steps: one each STEP_M of ground travel at a walk or a run, on their own quiet player.
const STEP_M := 1.15
const STEP_DB := -21.0
## Glances (personality only): what he may look at, how near, and how long a look lasts.
const LOOK_SCAN_S := 0.25
const LOOK_FOOD_M := 5.5
const LOOK_THREAT_M := 8.0
const LOOK_VORTEX_M := 12.0
const LOOK_HOLD_S := 1.6
const LOOK_REST_MIN := 2.0
const LOOK_REST_MAX := 4.5

var g: Game
var p: Axolotl
var _pace := []          # [time, speed] samples over PACE_WINDOW
var _t := 0.0
var _scuff_cd := 0.0
var _edge_seen := 0
var _teeter_cd := 0.0
var _step_m := 0.0
var _step_side := 1.0
var _step_player: AudioStreamPlayer3D
var _look_scan := 0.0
var _look_hold := 0.0
var _look_rest := 0.0
var _look_node: Node3D = null
var _look_pos := Vector3.INF
## What fired (tests and diagnostics): event name -> count.
var counts := {}


func _init() -> void:
	inst = self


func _ready() -> void:
	_step_player = AudioStreamPlayer3D.new()
	_step_player.bus = "SFX"
	_step_player.unit_size = 4.0
	_step_player.max_distance = 30.0
	add_child(_step_player)


func attach(game: Game, player: Axolotl) -> void:
	g = game
	p = player
	_edge_seen = p.edge_stops
	p.jumped.connect(_on_jumped)


func _count(what: String) -> void:
	counts[what] = int(counts.get(what, 0)) + 1


func _live() -> bool:
	return enabled and g != null and p != null and is_instance_valid(p) and g.state == "play"


# --- Events (called by the game where they happen, after the real thing is applied) -------------

## A soft landing (Axolotl._on_land): a squash springing back, and a small ring of silt when he
## came down with some weight. `impact` is the landing speed already used by the landing sound.
func on_soft_land(impact: float) -> void:
	if not _live():
		return
	var k := clampf((impact - 1.5) / 7.0, 0.2, 1.0)
	p.model.soft_land(k)
	if impact > 3.0:
		WaterFX.inst.touch_ring(p.global_position, p.up, 0.35 + 0.35 * k, 3 + int(round(4.0 * k)))
	_count("soft_land")


## The push-off (the axolotl's `jumped` signal, after the jump is applied): a stretch and a kick of
## silt at his feet. Nothing waits for it.
func _on_jumped() -> void:
	if not _live():
		return
	p.model.takeoff()
	var back := -p.velocity.normalized() if p.velocity.length() > 0.5 else -p.up
	back -= p.up * back.dot(p.up)
	WaterFX.inst.silt_kick(p.global_position, p.up, back.normalized() if back.length() > 0.05 else Vector3.ZERO, 5, 0.9)
	_count("takeoff")


## Eating (Game._eat, after the food's healing was applied): a gulp sized by the prey, its own pitch,
## a light haptic and a happy wriggle; the food itself is drawn into his mouth (Food.eaten).
## `weight`: 0 shrimp .. 1 worm.
func on_eat(f: Food) -> void:
	if not _live():
		return
	var weight: float = [0.45, 0.7, 1.0][f.type]
	p.model.gulp(weight)
	if f.type != Food.Type.BURROWER:
		# (The worm already has the full happy wriggle; the small prey get its tail end.)
		if p.model.happy_t < 0.0:
			p.model.happy_t = 0.35
	Settings.haptic("tap")
	_count("eat")


## The food's sound for its type: the shrimp light and high, the water flea a little lower, the
## worm its own big gulp (Game._eat plays this in place of the plain "eat").
static func eat_sound(f: Food) -> Array:
	if not enabled:
		return ["eat_big" if f.type == Food.Type.BURROWER else "eat", 1.0]
	match f.type:
		Food.Type.DRIFTER: return ["eat", 1.18]
		Food.Type.DARTER: return ["eat", 0.94]
	return ["eat_big", 1.0]


## Landed from a water tunnel (Game._cine_land's end): a soft touchdown ring, the soft landing
## sound and a small settle.
func on_arrival() -> void:
	if not _live():
		return
	p.model.soft_land(0.6)
	WaterFX.inst.touch_ring(p.global_position, p.up, 0.6, 8)
	Sfx.play("land_soft", p.global_position, -6.0)
	_count("arrival")


## Into a water tunnel: a short, light haptic (the opening shot already has its long one).
func on_vortex_enter() -> void:
	if not enabled:
		return
	Settings.haptic("land")
	_count("vortex_enter")


## A moss ball reached 100% for the first time this run (Game._on_restoration_changed): the
## aquarium breathes out. A sting, Gill's delight, a gentle haptic, one short line, a rising of
## bubbles and light round him and the plants swaying out. Never takes control; if he is not in
## ordinary play (a cinematic, dead) only the sound and the line come.
func on_ball_restored(b: MossBall) -> void:
	if not enabled or g == null:
		return
	Sfx.play("ball_restored", null, -3.0, 0.0)
	Settings.haptic("land")
	g.hud.show_discovery("%s is fully restored" % (b.display_name if b.display_name != "" else "This moss ball"))
	_count("ball_restored")
	if not _live() or p.state != "normal" or p.ball != b:
		return
	p.model.happy_t = 0.0
	if g.wake != null:
		g.wake.add_blast(p.global_position, 9.0, 3.0)
	_celebrate_bubbles(0)


## The celebration's bubbles and sparkles, in three timed waves (never per frame).
func _celebrate_bubbles(wave: int) -> void:
	if wave > 2 or not _live():
		return
	var c := p.body_center()
	for i in 4:
		var d := Vector3(_fx_rng.randf() - 0.5, _fx_rng.randf() * 0.3, _fx_rng.randf() - 0.5).normalized()
		WaterFX.inst.bubbles(c + d * _fx_rng.randf_range(0.8, 2.2), p.up, 2)
	WaterFX.inst.sparkle(c + p.up * 0.6, Color(0.6, 1.0, 0.75, 0.9), 8, 1.4, 0.07, 1.4)
	get_tree().create_timer(0.45).timeout.connect(func() -> void: _celebrate_bubbles(wave + 1))


## A cave's pickup (Game.upgrade_collected, after it was applied): the item's light streams into
## him (a pearl in its own peach, with its own sound); a health upgrade's new frond grows in.
## Pearls keep their gameplay exactly (a full refill); only how they look and sound is theirs.
func on_upgrade(u: Node3D, kind: String) -> void:
	if not _live():
		return
	var pearl := kind == "pearl"
	WaterFX.inst.wisp(u.global_position, p.body_center(), 0.45, PEARL if pearl else UPGRADE, 12)
	if pearl:
		Sfx.play("pearl", p.global_position, -2.0, 0.02)
	else:
		var i := p.max_health - 1
		p.model.grow_frond(i)
		p.model.restore_fronds_slowly(i, i + 1, 1.1)
	_count("pearl" if pearl else "upgrade")


## The upgrade's sparkle colour (a pearl's own peach; else the aqua it always had).
static func upgrade_colour(kind: String) -> Color:
	return PEARL if enabled and kind == "pearl" else UPGRADE


# --- Every frame: a few cheap reads -----------------------------------------------------------------

func _process(dt: float) -> void:
	if not _live():
		if p != null and is_instance_valid(p) and p.model.invuln != 0.0:
			p.model.invuln = 0.0
		if p != null and is_instance_valid(p):
			p.model.has_look = false
		return
	_t += dt
	_scuff_cd = maxf(0.0, _scuff_cd - dt)
	_teeter_cd = maxf(0.0, _teeter_cd - dt)
	_update_invuln(dt)
	_update_pace()
	_update_edge()
	_update_steps(dt)
	_update_look(dt)


## His existing invulnerability (Axolotl.invuln_t, its own timer, untouched): a soft shimmer that
## fades in and out with it.
func _update_invuln(dt: float) -> void:
	var want := 1.0 if p.invuln_t > 0.0 and p.state == "normal" else 0.0
	if p.invuln_t > 0.0 and p.invuln_t < 0.25:
		want = p.invuln_t / 0.25
	p.model.invuln = move_toward(p.model.invuln, want, dt * 6.0)


func _ground_speed() -> float:
	var v := p.velocity - p.up * p.velocity.dot(p.up)
	return v.length()


## Starting off and pulling up: a few puffs behind his feet (start) or ahead of them (stop), and on
## a stop a small settle. Only a real change of pace on the ground, then a cool-down.
func _update_pace() -> void:
	var sp := _ground_speed()
	_pace.append([_t, sp])
	while not _pace.is_empty() and _t - float(_pace[0][0]) > PACE_WINDOW:
		_pace.pop_front()
	if _scuff_cd > 0.0 or not p.grounded or p.state != "normal" or g.cinematic != "" or _pace.size() < 2:
		return
	var lo := INF
	var hi := 0.0
	for s in _pace:
		lo = minf(lo, float(s[1]))
		hi = maxf(hi, float(s[1]))
	var first := float(_pace[0][1])
	var v := p.velocity - p.up * p.velocity.dot(p.up)
	if first <= START_FROM and sp >= START_TO and lo <= START_FROM:
		WaterFX.inst.silt_kick(p.global_position, p.up, -v.normalized(), 3, 0.7)
		_scuff_cd = SCUFF_COOLDOWN
		_count("start")
	elif first >= STOP_FROM and sp <= STOP_TO and hi >= STOP_FROM:
		WaterFX.inst.silt_kick(p.global_position + p.facing * 0.35, p.up, p.facing, 3, 0.6)
		p.model.soft_land(0.25)
		_scuff_cd = SCUFF_COOLDOWN
		_count("stop")


## The edge assist (Axolotl._edge_stop) stopped him at a ravine's rim: he teeters a moment.
## Read from its own counter; nothing about the assist changes.
func _update_edge() -> void:
	if p.edge_stops == _edge_seen:
		return
	_edge_seen = p.edge_stops
	if _teeter_cd > 0.0:
		return
	p.model.teeter()
	WaterFX.inst.silt_kick(p.head_position(), p.up, p.facing, 2, 0.5)
	_teeter_cd = 1.2
	_count("teeter")


## Soft moss steps: one each STEP_M of travel on the ground, quiet and varied, on their own player
## (never taking a voice from the shared pool).
func _update_steps(dt: float) -> void:
	if not p.grounded or p.state != "normal" or g.cinematic != "":
		_step_m = 0.0
		return
	var sp := _ground_speed()
	if sp < 1.2:
		_step_m = minf(_step_m, STEP_M * 0.5)
		return
	_step_m += sp * dt
	if _step_m < STEP_M:
		return
	_step_m -= STEP_M
	var s := Sfx.inst.stream("moss_step") if Sfx.inst != null else null
	if s == null:
		return
	_step_side = -_step_side
	_step_player.stream = s
	_step_player.global_position = p.global_position + p.facing.cross(p.up) * 0.15 * _step_side
	_step_player.volume_db = STEP_DB + 3.0 * clampf((sp - 2.0) / 4.0, 0.0, 1.0) + _fx_rng.randf_range(-1.5, 1.5)
	_step_player.pitch_scale = _fx_rng.randf_range(0.88, 1.12)
	_step_player.play()
	_count("step")


## Glances (personality only): now and then, calm, he looks at something near and in front of him:
## a winding-up parasite first, else food, else an open water tunnel. Never while he is lunging,
## swiping, landing or idling (the model checks), never a snap (eased in and out), never anything
## the game reads: only the head turns. A look lasts LOOK_HOLD_S, then a rest.
func _update_look(dt: float) -> void:
	_look_hold = maxf(0.0, _look_hold - dt)
	_look_rest = maxf(0.0, _look_rest - dt)
	if _look_hold > 0.0:
		if _look_node != null and is_instance_valid(_look_node) and _look_node.is_inside_tree():
			p.model.look_target = _look_node.global_position
		elif _look_pos != Vector3.INF:
			p.model.look_target = _look_pos
		if _look_hold <= 0.0 or _ground_speed() > Axolotl.RUN_SPEED * 0.9:
			_end_look()
		return
	if p.model.has_look:
		_end_look()
	_look_scan -= dt
	if _look_scan > 0.0 or _look_rest > 0.0 or p.state != "normal" or g.cinematic != "":
		return
	_look_scan = LOOK_SCAN_S
	var pick := _look_pick()
	if pick.is_empty():
		return
	_look_node = pick[0]
	_look_pos = pick[1]
	p.model.look_target = _look_pos
	p.model.has_look = true
	_look_hold = LOOK_HOLD_S
	_count("look")


func _end_look() -> void:
	p.model.has_look = false
	_look_node = null
	_look_pos = Vector3.INF
	_look_hold = 0.0
	_look_rest = _fx_rng.randf_range(LOOK_REST_MIN, LOOK_REST_MAX)


## [node, position] of the best thing to glance at, or [] for none. In front of him (within ~70 deg).
func _look_pick() -> Array:
	var here := p.head_position()
	var best := []
	var best_d := INF
	for par in p.ball.hostiles():
		if par.is_alive() and par.state == "windup":
			var d: float = par.global_position.distance_to(here)
			if d < LOOK_THREAT_M and d < best_d and _in_front(par.global_position):
				best = [par, par.global_position]
				best_d = d
	if not best.is_empty():
		return best
	for f in p.ball.foods:
		if is_instance_valid(f) and f.is_catchable():
			var d: float = f.global_position.distance_to(here)
			if d < LOOK_FOOD_M and d < best_d and _in_front(f.global_position):
				best = [f, f.global_position]
				best_d = d
	if not best.is_empty():
		return best
	for v in g.vortices:
		if not v.connected:
			continue
		for at_b in [false, true]:
			if (v.ball_b if at_b else v.ball_a) != p.ball:
				continue
			var m: Vector3 = v.mouth_pos(at_b)
			var d := m.distance_to(here)
			if d < LOOK_VORTEX_M and d < best_d and _in_front(m):
				best = [null, m]
				best_d = d
	return best


func _in_front(pos: Vector3) -> bool:
	var to := pos - p.head_position()
	to -= p.up * to.dot(p.up)
	return to.length() > 0.3 and to.normalized().dot(p.facing) > 0.35


# --- Timed emission (v107: cosmetic density no longer follows the frame rate) --------------------

var _emit := {}


## How many of an effect to emit now for a stream running at `rate` per second under key `key`:
## accumulates real time, so 30 fps and 120 fps give the same density.
func emit_count(key: String, dt: float, rate: float) -> int:
	var acc := float(_emit.get(key, 0.0)) + dt * rate
	var n := int(acc)
	_emit[key] = acc - n
	return n


static func emit_now(key: String, dt: float, rate: float) -> int:
	if inst == null:
		return 1 if dt > 0.0 else 0
	return inst.emit_count(key, dt, rate)
