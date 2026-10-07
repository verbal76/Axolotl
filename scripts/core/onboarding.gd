class_name Onboarding
extends Node
## Onboarding (docs/ONBOARDING.md, ledger rows 20 and 24): the intro screen, then three lessons, all
## once per RUN while Settings.tutorials is on: feeding (his fronds are his health), the first
## parasite (removing parasites restores the moss) and the first Red Starfish (Skills).
##
## Rules this keeps:
## - Flags live in the run save (RunSave.lessons): Continue keeps them, New Run starts them again.
##   A run saved before that record existed counts every lesson as done (Game._setup_onboarding).
## - Tutorials off: every lesson reads as done (nothing starts, no frond is emptied) without being
##   marked, so turning them back on mid-run lets this run's remaining lessons still come.
## - Everything here is presentation. The food's healing, the kill, its restoration and completion
##   are applied by Game exactly as without a lesson; a lesson only stages how they are SHOWN (the
##   frond's colour returning, the moss's reveal front), moves the camera and shows a card.
## - No random numbers are drawn and no simulation timing changes (no time scale, no pause).
## - A staged moment always ends: a hard time cap, and it ends cleanly on pause, the app going to
##   the background, leaving play, or Gill not being in normal play. Input is always given back.
##   The flag is set the moment the event happens, so an interrupted lesson is never replayed.
## - During the interactive parts (find and eat the jellyfish, defeat the parasite) Gill is never
##   held: only a small objective and the real control's prompt are shown.

const FLAGS := ["intro", "feeding", "parasite", "starfish", "tunnel"]

## A staged moment is given back after this long at the most, card or not (seconds).
const STAGE_CAP := 45.0
## The parasite lesson: the camera rises for this long, then the moss is revealed over REVEAL_S.
const RISE_S := 0.9
const REVEAL_S := 5.0
const HOLD_S := 0.8
## The feeding lesson: the camera comes in, then the frond comes back over FROND_S.
const CLOSE_S := 1.0
const FROND_S := 1.3
## How near a target must be, and how often the view is checked for one.
const FOOD_SEE_M := 16.0
const PARASITE_SEE_M := 13.0
const SCAN_S := 0.2

static var FEED_TITLE: String = "FOOD HEALS %s" % GameVersion.CHARACTER_NAME.to_upper()
# (The character's name comes from GameVersion, never typed here; the owner's wording is otherwise verbatim.)
static var FEED_BODY: Array = ["%s's glowing fronds are his health." % GameVersion.CHARACTER_NAME, "Food restores them."]
const KILL_TITLE := "DID YOU SEE THAT?"
const KILL_BODY := ["Removing parasites lets the moss recover."]
const STAR_TITLE := "RED STARFISH FOUND!"
static var STAR_BODY: Array = ["%s found a Red Starfish!" % GameVersion.CHARACTER_NAME, "Spend Red Starfish on new abilities in the Skills tab, available from the Main Menu or Settings."]
static var INTRO_TITLE: String = "THIS IS %s'S HOME." % GameVersion.CHARACTER_NAME.to_upper()
static var INTRO_BODY: Array = ["Parasites have infested the aquarium and damaged the moss balls he lives among.",
		"Help %s clear them out and bring his home back to life." % GameVersion.CHARACTER_NAME]
const TUNNEL_TITLE := "A WATER TUNNEL OPENED!"
static var TUNNEL_BODY: Array = ["This is a water tunnel.",
		"Once you have a moss ball almost completely cleared, it'll let you travel to another. Swim into the swirl to ride it."]
const OBJ_FEED := "EAT THE JELLYFISH"
const OBJ_PARASITE := "DEFEAT THE PARASITE"

var g: Game
var ui: OnboardingUi
## What runs once the card now up is closed (the tunnel card's shot), if anything.
var _after_card := Callable()

## The staged moment in progress: "" | "feed" | "kill" | "star" | "card" (waiting for Got it).
var stage := ""
var stage_t := 0.0
## Which lesson the stage belongs to ("feeding", "parasite", "starfish").
var stage_lesson := ""
## Why the last stage ended ("done", "cap", "pause", "background", "left play", "state").
var last_end := ""
## The interactive objective on screen: "" | "feeding" | "parasite".
var objective := ""
var food_target: Food = null
var parasite_target: Parasite = null
## This run started with the lesson's empty frond (saved in the run's record, so a Continue keeps it).
var run_frond := false
var _scan := 0.0
var _feed := {}
var _kill := {}
var _lunge_shown := false
var _swipe_shown := false
var _camera_prompt_after := false
## Set between wants_kill_stage and begin_kill (the kill's own signals fire in between).
var _kill_claim := false
var _intro_cb := Callable()
## A stage's end reasons seen this session (tests).
var ends: Array[String] = []


func _ready() -> void:
	# (Runs while the tree is paused, so it can notice the pause and end a staged moment cleanly.)
	process_mode = Node.PROCESS_MODE_ALWAYS


## Done in this run, or tutorials are off, or the run has no record (one from before it existed).
func done(flag: String) -> bool:
	if not Settings.tutorials:
		return true
	var rs := g.run_save
	return rs == null or not rs.has_lessons() or rs.lessons().has(flag)


func all_done() -> bool:
	for f in FLAGS:
		if not done(f):
			return false
	return true


## Marks a lesson done in this run and writes the run at once (an interrupted lesson is never
## replayed in it).
func _mark(flag: String) -> void:
	var rs := g.run_save
	if rs == null or not rs.has_lessons() or rs.lessons().has(flag):
		return
	rs.lessons()[flag] = true
	g.save_run()


## The record for this run: a new run's (nothing done), or every lesson done (a run from before the
## record existed, and the test switch).
func record_for_new_run() -> void:
	g.run_save.set_lessons({})
	run_frond = false


func record_all_done() -> void:
	var d := {}
	for f in FLAGS:
		d[f] = true
	g.run_save.set_lessons(d)
	run_frond = false


## Settings' Tutorials toggle. Off: an objective or a staged lesson ends now (cleanly, as on any
## other exit). On: nothing starts by itself; this run's lessons not yet done may still come.
func tutorials_changed(on: bool) -> void:
	if on:
		return
	if stage != "":
		finish("off")
	_set_objective("")


# --- Intro ------------------------------------------------------------------------------------

## The intro shows when a genuinely new run starts (Play with no saved run, or New Run) while
## tutorials are on: every new run. Continue never shows it.
func intro_due(continuing: bool) -> bool:
	return not continuing and not done("intro")


func show_intro(cb: Callable) -> void:
	_intro_cb = cb
	ui.show_card(INTRO_TITLE, INTRO_BODY, "Begin", _on_intro_begin, true)


func intro_showing() -> bool:
	return ui.card_kind() == "intro"


func _on_intro_begin() -> void:
	ui.hide_card()
	_mark("intro")
	var cb := _intro_cb
	_intro_cb = Callable()
	if cb.is_valid():
		cb.call()


# --- Play starts ------------------------------------------------------------------------------

## Called by Game.start_play. A new run, tutorials on: one unlocked frond starts empty, so the first
## jellyfish visibly heals him; a Continue of that run keeps it empty until the lesson is done.
## Tutorials off: none (he starts at full health).
func on_play_started(continuing: bool) -> void:
	var rs := g.run_save
	run_frond = rs != null and bool(rs.lessons().get("frond", false))
	if done("feeding"):
		return
	if not continuing and not run_frond:
		run_frond = true
		rs.lessons()["frond"] = true
		g._save_dirty = true
	if run_frond:
		var p := g.player
		if p.health == p.max_health and p.max_health > 1:
			p.health -= 1
			p.model.set_health(p.health, p.max_health, false)
			p.health_changed.emit(p.health, p.max_health)


# --- Every frame --------------------------------------------------------------------------------

func _process(dt: float) -> void:
	if g == null or g.player == null:
		return
	if stage != "":
		if get_tree().paused:
			finish("pause")
			return
		if g.state != "play":
			finish("left play")
			return
		stage_t += dt
		if stage_t > STAGE_CAP:
			finish("cap")
			return
		match stage:
			"feed": _update_feed()
			"kill": _update_kill()
		return
	if get_tree().paused:
		return
	_scan -= dt
	if _scan <= 0.0:
		_scan = SCAN_S
		_update_objective()
	ui.update_marker(_marker_pos())


## The app went to the background (or lost focus): a staged moment ends cleanly.
func interrupt(why: String) -> void:
	if stage != "":
		finish(why)


# --- The interactive objectives -----------------------------------------------------------------

func _playing() -> bool:
	var p := g.player
	return g.state == "play" and g.cinematic == "" and p.state == "normal" and p.controls_enabled \
			and (g.presentation == null or not g.presentation.active())


func _update_objective() -> void:
	var want := ""
	if _playing():
		# Owner, 2026-10-01: the food lesson starts the first time a jellyfish comes into view
		# (he starts a frond down for it), ahead of the parasite; a parasite lesson already
		# under way is not interrupted.
		var hungry := not done("feeding") and g.player.health < g.player.max_health
		if objective != "parasite" and hungry and _find_food():
			want = "feeding"
		elif not done("parasite") and _find_parasite():
			want = "parasite"
		elif hungry and _find_food():
			want = "feeding"
	_set_objective(want)


func _set_objective(want: String) -> void:
	if want != "feeding" and food_target != null:
		_release_food()
	if want != "parasite":
		parasite_target = null
	if want == "":
		ui.update_marker(Vector3.INF)
	if want == objective:
		return
	objective = want
	match want:
		"feeding":
			ui.show_objective(OBJ_FEED)
		"parasite":
			ui.show_objective(OBJ_PARASITE)
		_:
			ui.hide_objective()
	_prompt("lunge", want == "feeding")
	_prompt("swipe", want == "parasite")


## The real control's prompt (the HUD's pulsing ring on the Lunge or Tail Swipe button).
func _prompt(name_: String, on: bool) -> void:
	var shown := _lunge_shown if name_ == "lunge" else _swipe_shown
	if on == shown:
		return
	if name_ == "lunge":
		_lunge_shown = on
	else:
		_swipe_shown = on
	if on:
		g.hud.show_prompt(name_)
	elif not g.prompts_active.has(name_):
		g.hud.hide_prompt(name_)


## Whether `pos` is really in view: near, on screen (not at its very edge) and not behind terrain.
func visible_to_player(pos: Vector3, max_d: float, ignore: Object = null) -> bool:
	var cam := g.cam
	if pos.distance_to(g.player.global_position) > max_d or not cam.is_position_in_frustum(pos):
		return false
	var vp := cam.get_viewport().get_visible_rect().size
	var sp := cam.unproject_position(pos)
	if sp.x < vp.x * 0.03 or sp.x > vp.x * 0.97 or sp.y < vp.y * 0.06 or sp.y > vp.y * 0.97:
		return false
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, pos, 1 | 2)
	q.exclude = [g.player.get_rid()]
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit["collider"] == ignore or (hit["position"] as Vector3).distance_to(pos) < 0.8


func _food_ok(f) -> bool:  # (untyped: a freed jellyfish must read as "not ok", not error)
	return is_instance_valid(f) and f.type == Food.Type.DRIFTER and f.state == "idle" and f.is_catchable() \
			and f.ball == g.player.ball


## Keeps the current jellyfish while it is valid (wherever it is), else the nearest one in view.
func _find_food() -> bool:
	if _food_ok(food_target) and food_target.global_position.distance_to(g.player.global_position) < 40.0:
		return true
	_release_food()
	var best: Food = null
	var bd := INF
	for f in g.player.ball.foods:
		if not _food_ok(f):
			continue
		var d: float = f.global_position.distance_to(g.player.global_position)
		if d < bd and visible_to_player(f.global_position, FOOD_SEE_M):
			bd = d
			best = f
	if best == null:
		return false
	food_target = best
	best.anchor = best.global_position
	return true


func _release_food() -> void:
	if is_instance_valid(food_target):
		food_target.anchor = Vector3.INF
	food_target = null


func _find_parasite() -> bool:
	var pt := parasite_target
	if is_instance_valid(pt) and pt.is_alive() and pt.ball == g.player.ball and pt.global_position.distance_to(g.player.global_position) < 40.0:
		return true
	parasite_target = null
	var bd := INF
	for par in g.player.ball.parasites:
		if not par.is_alive():
			continue
		var d: float = par.global_position.distance_to(g.player.global_position)
		if d < bd and visible_to_player(par.global_position + g.player.ball.up_at(par.global_position) * 0.3, PARASITE_SEE_M, par):
			bd = d
			parasite_target = par
	return parasite_target != null


## Where the objective's marker is drawn (the target), or INF for none.
func _marker_pos() -> Vector3:
	if objective == "parasite" and is_instance_valid(parasite_target) and parasite_target.is_alive():
		return parasite_target.body_center()
	if objective == "feeding" and is_instance_valid(food_target):
		return food_target.global_position
	return Vector3.INF


# --- Lesson 1: feeding ----------------------------------------------------------------------------

## Game._eat, after the food's healing was applied (exactly as always): `before` is his health
## before it. The visible frond restore is held back until the camera is close.
func on_food_eaten(before: int) -> void:
	var p := g.player
	if done("feeding") or p.health <= before:
		return
	run_frond = false
	g.run_save.lessons().erase("frond")
	_mark("feeding")
	_release_food()
	_set_objective("")
	if not _can_stage():
		return
	p.model.set_health(before, p.max_health, false)
	_feed = {"from": before, "to": p.health, "restored": false}
	_begin("feed", "feeding", true)


func _update_feed() -> void:
	var p := g.player
	var head := p.head_position()
	var right := p.facing.cross(p.up).normalized()
	# Close on his head from the front and a little to the side: the fronds fill the frame.
	g.cam.cine_pos = head + p.facing * 1.35 + p.up * 0.5 + right * 0.55
	g.cam.cine_look = head + p.up * 0.12 - p.facing * 0.1
	g.cam.cine_up = p.up
	if not _feed["restored"] and stage_t >= CLOSE_S:
		_feed["restored"] = true
		p.model.restore_fronds_slowly(_feed["from"], _feed["to"], FROND_S)
		p.model.set_health(p.health, p.max_health, false)
		Sfx.play("upgrade", p.global_position, -10.0)
	if _feed["restored"] and stage_t >= CLOSE_S + FROND_S + 0.5:
		_card(FEED_TITLE, FEED_BODY)


# --- Lesson 2: the first parasite -----------------------------------------------------------------

## Game.parasite_killed asks this BEFORE applying the kill: true when this kill is the lesson's and
## will be staged (Game then hands over the snapshot and the splats; see begin_kill).
func wants_kill_stage() -> bool:
	_kill_claim = not done("parasite") and stage == "" and _can_stage()
	return _kill_claim


## After the kill was applied exactly as always: `base` is the moss as drawn before it and `splats`
## the restoration it added ([dir, angle]). Its reveal is paced; the camera rises to watch.
func begin_kill(par: Parasite, ball: MossBall, base: Image, splats: Array) -> void:
	_kill_claim = false
	_mark("parasite")
	parasite_target = null
	_set_objective("")
	var center := ball.up_at(par.global_position)
	var outer := 0.0
	for s in splats:
		outer = maxf(outer, acos(clampf(center.dot(s[0]), -1.0, 1.0)) + float(s[1]))
	outer = minf(outer + 0.02, PI)
	ball.stage_begin(center, outer, base)
	_kill = {"ball": ball, "center": center, "outer": outer, "pos": ball.surface_point(center)}
	_begin("kill", "parasite", true)
	_kill_camera()


## Marks the lesson done when a kill cannot be staged (it has happened; it is never replayed).
func kill_unstaged() -> void:
	if not done("parasite"):
		_mark("parasite")
		parasite_target = null
		_set_objective("")


## Whether the tutorial's own framing shot should give way (the lesson's shot shows the same).
func claims_frame() -> bool:
	if stage == "kill" or _kill_claim:
		_camera_prompt_after = true
		return true
	return false


func _kill_camera() -> void:
	var ball: MossBall = _kill["ball"]
	var p := g.player
	var gpos := p.body_center()
	var kpos: Vector3 = _kill["pos"]
	var up := ball.up_at(gpos.lerp(kpos, 0.5))
	# The reveal's size on the ground (the arc of its outer angle) sets how far up and out to go.
	var reach := ball.radius * float(_kill["outer"])
	var away := gpos - kpos
	away -= up * away.dot(up)
	if away.length() < 0.5:
		away = -p.facing - up * (-p.facing).dot(up)
	away = away.normalized()
	var look := gpos.lerp(kpos, 0.55)
	var dist := clampf(reach * 1.15 + 4.0, 8.0, 26.0)
	_kill["cam_pos"] = gpos + away * dist * 0.55 + up * dist * 0.85
	_kill["cam_look"] = look
	_kill["cam_up"] = up
	g.cam.cine_pos = _kill["cam_pos"]
	g.cam.cine_look = look
	g.cam.cine_up = up


func _update_kill() -> void:
	var ball: MossBall = _kill["ball"]
	g.cam.cine_pos = _kill["cam_pos"]
	g.cam.cine_look = _kill["cam_look"]
	g.cam.cine_up = _kill["cam_up"]
	var k := clampf((stage_t - RISE_S) / REVEAL_S, 0.0, 1.0)
	# Eased in and out, slowing a little toward the edge as it spreads.
	var e := 1.0 - pow(1.0 - smoothstep(0.0, 1.0, k), 1.4)
	ball.stage_set((float(_kill["outer"]) + 0.05) * e)
	if k >= 1.0 and stage_t >= RISE_S + REVEAL_S + HOLD_S:
		ball.stage_end()
		_card(KILL_TITLE, KILL_BODY)


# --- Lesson 3: the first Red Starfish ----------------------------------------------------------------

## StarfishField.collect, after the pickup was recorded: an informational card, no camera move.
func on_starfish() -> void:
	if done("starfish"):
		return
	_mark("starfish")
	if not _can_stage():
		return
	_begin("star", "starfish", false)
	_card(STAR_TITLE, STAR_BODY)


# --- Lesson 4: the first water tunnel -----------------------------------------------------------------

## Once per run, a card that says what a water tunnel is (owner, 2026-10-01). Owner, 2026-10-07: it
## comes FIRST, over the ordinary view of Gill, and the tunnel-opening shot plays after "Got it"
## (`then`); and it is never lost: the lesson is recorded only once the card is up (a moment it
## cannot be shown, paused or mid-cinematic, it waits), and a run with a tunnel already open whose
## card was never seen gets it at the next calm moment (Game._check_vortex_connections).
func tunnel_card_owed() -> bool:
	return not done("tunnel")


## A missed tunnel card waits its turn: never over another lesson or its objective, and only once
## the core lessons (intro, feeding, parasite) are behind him (the tunnel is the last lesson).
func tunnel_card_may_catch_up() -> bool:
	return tunnel_card_owed() and objective == "" and stage == "" and done("intro") and done("feeding") and done("parasite")


## Shows the tunnel card now if it can (returns whether it is up); `then` runs once it is closed.
func show_tunnel_card(then := Callable()) -> bool:
	if done("tunnel") or stage != "" or not _can_stage():
		return false
	_mark("tunnel")
	_begin("tunnel", "tunnel", false)
	_after_card = then
	_card(TUNNEL_TITLE, TUNNEL_BODY)
	return true


# --- Staged moments ---------------------------------------------------------------------------------

func _can_stage() -> bool:
	var p := g.player
	return g.state == "play" and g.cinematic == "" and p.state == "normal" and not get_tree().paused


func _begin(kind: String, lesson: String, camera: bool) -> void:
	stage = kind
	stage_lesson = lesson
	stage_t = 0.0
	g._start_cinematic("lesson", {})
	g.cam.cinematic = camera


func _card(title: String, body: Array) -> void:
	stage = "card"
	ui.show_card(title, body, "Got it", func() -> void: finish("done"))


## Ends the staged moment now, whatever it was doing: the presentation is brought to the true state
## (the frond lit, the moss as it is), the card closes and control is given back.
func finish(why: String) -> void:
	if stage == "":
		return
	last_end = why
	ends.append("%s:%s" % [stage_lesson, why])
	if _kill.has("ball") and is_instance_valid(_kill["ball"]):
		(_kill["ball"] as MossBall).stage_end()
	if _feed.has("to") and not _feed.get("restored", true):
		g.player.model.set_health(g.player.health, g.player.max_health, false)
	_kill = {}
	_feed = {}
	stage = ""
	stage_lesson = ""
	if ui.card_kind() != "intro":
		ui.hide_card()
	if g.cinematic == "lesson":
		g._end_cinematic()
	if _after_card.is_valid():
		var then := _after_card
		_after_card = Callable()
		then.call_deferred()
	if _camera_prompt_after:
		_camera_prompt_after = false
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if is_instance_valid(g) and g.state == "play":
				g._show_prompt("camera"))


func staging() -> bool:
	return stage != ""


## Diagnostics line.
func status_text() -> String:
	var L: Array[String] = []
	var rs := g.run_save
	for f in FLAGS:
		L.append("%s %s" % [f, "done" if rs != null and rs.lessons().has(f) else "-"])
	var rec := "this run: " + ", ".join(L) if rs != null and rs.has_lessons() else "no record (a run from before it: all done)"
	return "Tutorials %s; %s; stage '%s', objective '%s'" % ["on" if Settings.tutorials else "off", rec, stage, objective]
