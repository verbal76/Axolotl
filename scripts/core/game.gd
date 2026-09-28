class_name Game
extends Node3D
## Root of the experience: builds the aquarium, three moss balls, the axolotl and UI, and
## runs the systems that connect them (combat, restoration, checkpoints, vortices,
## tutorial prompts, food repopulation, completion).

static var inst: Game

signal restoration_event(ball_index: int)
signal all_clear
signal startup_finished

var env: Environment
var aquarium: Aquarium
var water_fx: WaterFX
var sfx: Sfx
var audio: AudioDirector
## The movers' disturbance in the vegetation (cosmetic only).
var wake: Wake
## Expansion 5's creatures: placement, activation near the axolotl, discovery (docs/ECOSYSTEM.md).
var ecosystem: Ecosystem
var balls: Array[MossBall] = []
var vortices: Array[Vortex] = []
var player: Axolotl
var cam: FollowCam
var hud: Hud
var title: TitleScreen
var pause_menu: PauseMenu
var quality: QualityScaler

var state := "title"          # title | play
var cinematic := ""
var cine_t := 0.0
var cine_data := {}
var checkpoint: Bloom = null
var g_target := 0.0
var g_disp := 0.0
var ball_disp: Array[float] = []
var prompts_done := {}
var prompts_active := {}
var all_clear_done := false
var _all_clear_wait := -1.0
var _tut_framed := false
var _mote_lights: Array[OmniLight3D] = []
var _food_timer := 0.0
var _vortex_block: Vortex = null
var _pending_connect: Array = []
var _moved := 0.0
var _last_pos := Vector3.ZERO
var _camera_moved := false
var _title_t := 0.0
var _regen_from := Vector3.ZERO
## Mote's loading screen, on top until the first usable frame has been drawn.
var loading: LoadingScreen
## True once the whole world is built and the first usable frame has been handed over.
var ready_done := false
## The stages the loading screen showed this launch.
var loading_stages: Array[String] = []
## The completion catalog (every completion-bearing thing, with stable ids) and this run's save
## and clock. Only _earn() reports completion; only Completion computes percentages.
var completion: Completion
var run_save: RunSave
var clock: RunClock
var _autosave_t := 0.0
## Continuing a run: the ball to resume on, until its bloom has settled (see _resume_position).
var _resume_ball := -1
var _save_dirty := false
var stats := {"kills": 0, "motes": 0, "eaten": [0, 0, 0], "upgrades": 0, "deaths": 0, "extreme_landings": 0, "hard_landings": 0,
		"travels": [], "connects": []}


func _init() -> void:
	inst = self
	add_to_group("mote_game")


## Startup is staged so the first frame is Mote's loading screen, not a dark splash: the world
## is then built one stage per frame (nothing plays meanwhile; the game subtree is disabled so
## seeded runs stay deterministic), and the loading screen stays on top until the first frame
## of the real world, whose GPU pipelines are compiled behind it, has been drawn.
func _ready() -> void:
	StartupTrace.mark("main scene: Game._ready begins")
	process_mode = Node.PROCESS_MODE_DISABLED
	visible = false
	loading = LoadingScreen.new()
	add_child(loading)
	await _drawn()
	StartupTrace.mark("first frame drawn: Mote loading screen visible")
	await _build_world()
	_open_run()
	process_mode = Node.PROCESS_MODE_INHERIT
	if Settings.skip_title or Settings.test_mode != "":
		start_play(true)
	else:
		_enter_title()
	StartupTrace.mark("world ready (%s); first world frame requested" % state)
	await _drawn()
	StartupTrace.mark("first frame drawn: %s usable" % state)
	loading_stages = loading.stages.duplicate()
	loading.finish()
	ready_done = true
	startup_finished.emit()
	if Settings.test_mode != "":
		var t: Node = load("res://scripts/tests/test_runner.gd").new()
		add_child(t)
	if OS.get_cmdline_user_args().has("--startup-probe"):
		_startup_probe()


## Waits until the frame now being prepared has been drawn (headless runs draw nothing, so a
## processed frame stands in for it there).
func _drawn() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw


func _stage(text: String) -> void:
	loading.set_stage(text)
	await _drawn()


func _build_world() -> void:
	await _stage("Filling the aquarium")
	# Automated verification runs are seeded so a given build always plays out the same way.
	if Settings.test_mode != "":
		seed(int(Settings.test_args.get("seed", "4242")))
	else:
		randomize()
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_sky_affect = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	we.environment = env
	add_child(we)

	water_fx = WaterFX.new()
	add_child(water_fx)
	sfx = Sfx.new()
	add_child(sfx)
	wake = Wake.new()
	add_child(wake)
	audio = AudioDirector.new()
	add_child(audio)

	StartupTrace.mark("environment + audio nodes")
	aquarium = Aquarium.new()
	add_child(aquarium)
	aquarium.build(env)
	StartupTrace.mark("aquarium built")

	var n_balls := Levels.CENTERS.size()
	for i in n_balls:
		await _stage("Growing moss ball %d of %d" % [i + 1, n_balls])
		var b := Levels.build_ball(i, self)
		b.event_restored.connect(_on_event_restored)
		b.zone_completed.connect(_on_zone_completed)
		b.restoration_changed.connect(_on_restoration_changed)
		balls.append(b)
		ball_disp.append(0.0)
		StartupTrace.mark("moss ball %d built" % (i + 1))
	await _stage("Placing the axolotl and the vortices")
	for pair in Levels.LINKS:
		var v := Vortex.new()
		v.setup(balls[pair[0]], balls[pair[1]], Levels._vortex_dir(pair[0], pair[1]), Levels._vortex_dir(pair[1], pair[0]))
		add_child(v)
		vortices.append(v)

	player = Axolotl.new()
	add_child(player)
	var b0 := balls[0]
	player.place(b0, b0.surface_point(b0.start_dir, 0.1), -MossBall.frame_at(b0.start_dir, 180.0).z)
	player.died.connect(_on_player_died)
	player.jumped.connect(func(): notify_action("jump"))
	player.burst_used.connect(func(): notify_action("burst"))
	cam = FollowCam.new()
	add_child(cam)
	cam.target = player
	player.cam = cam
	# The camera goes live only in the last stage: until then nothing 3D is drawn, so the
	# loading screen keeps updating while GPU pipelines compile in the background.
	cam.snap_behind()
	_last_pos = player.global_position

	for i in 3:
		var l := OmniLight3D.new()
		l.light_color = Color(0.55, 1.0, 0.72)
		l.omni_range = 3.4
		l.omni_attenuation = 1.4
		l.light_energy = 0.0
		l.shadow_enabled = false
		add_child(l)
		_mote_lights.append(l)

	StartupTrace.mark("vortices, axolotl, camera, lights")
	for b in balls:
		_initial_food(b)
	StartupTrace.mark("food placed")
	ecosystem = Ecosystem.new()
	add_child(ecosystem)
	ecosystem.populate(balls)
	StartupTrace.mark("creatures placed")
	await _stage("Setting up the tank")

	hud = Hud.new()
	add_child(hud)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	title = TitleScreen.new()
	add_child(title)
	quality = QualityScaler.new()
	add_child(quality)

	audio.set_ball(0, false)
	aquarium.apply(0.0)
	StartupTrace.mark("HUD, menus, title built")
	await _stage("Preparing graphics (the first launch takes longest)")
	visible = true
	cam.current = true


## Measurement harness (desktop or device): report the timeline once the first usable frame has
## been drawn, then quit. Never used in normal play.
func _startup_probe() -> void:
	get_tree().process_frame.connect(func() -> void: StartupTrace.mark("probe: first process_frame (before _process)"), CONNECT_ONE_SHOT)
	get_tree().physics_frame.connect(func() -> void: StartupTrace.mark("probe: first physics_frame"), CONNECT_ONE_SHOT)
	RenderingServer.frame_pre_draw.connect(func() -> void: StartupTrace.mark("probe: first frame_pre_draw (scripts done)"), CONNECT_ONE_SHOT)
	while not StartupTrace.has("first frame drawn: %s usable" % state):
		await get_tree().process_frame
	var pc := {}
	for k in ["PIPELINE_COMPILATIONS_CANVAS", "PIPELINE_COMPILATIONS_MESH", "PIPELINE_COMPILATIONS_SURFACE", "PIPELINE_COMPILATIONS_DRAW", "PIPELINE_COMPILATIONS_SPECIALIZATION"]:
		if ClassDB.class_has_integer_constant("Performance", k):
			pc[k.trim_prefix("PIPELINE_COMPILATIONS_").to_lower()] = Performance.get_monitor(ClassDB.class_get_integer_constant("Performance", k))
	print("[STARTUP] pipeline compilations so far: ", pc)
	print("[STARTUP] timeline\n" + StartupTrace.timeline_text(Boot.get("boot_marks") if "boot_marks" in Boot else []))
	get_tree().quit()


# --- Flow --------------------------------------------------------------------------------

func _enter_title() -> void:
	state = "title"
	player.controls_enabled = false
	hud.visible_controls(false)
	title.show_title()
	cam.cinematic = true
	Boot.report_ready()


func start_play(immediate := false) -> void:
	state = "play"
	run_save.note_identity(Boot.identity())
	if clock.start():
		save_run()
	title.hide_title()
	hud.visible_controls(true)
	player.controls_enabled = true
	cam.cinematic = false
	if immediate:
		cam.snap_behind()
	Settings.skip_title = false
	_show_prompt("move")
	Boot.report_ready()


## New Run: a fresh run (world, completion, clock) straight into play. Records such as the best
## finish time are kept.
func restart_experience() -> void:
	run_save.start_new_run()
	run_save.save()
	get_tree().paused = false
	Settings.skip_title = true
	get_tree().reload_current_scene()


func return_to_title() -> void:
	save_run()
	get_tree().paused = false
	Settings.skip_title = false
	get_tree().reload_current_scene()


# --- Run save, clock and completion --------------------------------------------------------

static func run_save_path() -> String:
	if Settings.test_args.has("run-save"):
		return Settings.test_args["run-save"]
	# Automated runs never touch the player's run save.
	return "user://test_run.json" if Settings.test_mode != "" else RunSave.PATH


## After the world is built: the catalog stamps ids on the world, the run save is opened (tests
## start from a fresh one unless given their own file) and a run in progress is restored.
func _open_run() -> void:
	completion = Completion.build_from_world(balls, vortices)
	var path := run_save_path()
	if Settings.test_mode != "" and not Settings.test_args.has("run-save"):
		RunSave.erase(path)
	run_save = RunSave.open(path)
	clock = RunClock.from_dict(run_save.run()["clock"])
	_apply_run()
	StartupTrace.mark("run save opened (%s)" % run_save.origin.get_slice(" (", 0))


## True when there is a run to continue (the title then offers Continue and New Run).
func has_run_in_progress() -> bool:
	return clock.state != "not_started" or not run_save.earned().is_empty()


## Restores a saved run's world: everything earned is put back silently (no effects, no signals),
## then Gill is placed at the last bloom on the ball the run was on.
func _apply_run() -> void:
	var e := run_save.earned()
	var world: Dictionary = run_save.run().get("world", {})
	for b in balls:
		for par in b.parasites:
			if e.has(par.get_meta("completion_id", "")):
				par.restore_cleared()
				b.restore_event(par.zone_id, b.surface_point(par.spawn_dir))
		for m in b.motes:
			if e.has(m.get_meta("completion_id", "")):
				m.restore_done()
				b.restore_event(m.zone_id, b.surface_point(m.home_dir()))
		for u in b.upgrades:
			if e.has(u.get_meta("completion_id", "")):
				u.taken = true
				u.visible = false
				if u.get("kind") != "pearl":
					player.max_health = mini(6, player.max_health + 1)
		for bl in b.blooms:
			if e.has(bl.get_meta("completion_id", "")):
				bl.active = true
				if bl.get_meta("completion_id") == world.get("checkpoint", ""):
					checkpoint = bl
		ball_disp[b.index] = b.restoration
	for v in vortices:
		if e.has(v.get_meta("completion_id", "")):
			v.connected = true
	for c in ecosystem.all_critters():
		if c.threat_id != "" and e.has(c.threat_id):
			c.restore_defeated()
	player.restore_full()
	if world.is_empty():
		return
	for k in world.get("prompts_done", []):
		prompts_done[k] = true
	_tut_framed = bool(world.get("tut_framed", false))
	all_clear_done = bool(world.get("all_clear_shown", false))
	var st: Dictionary = world.get("stats", {})
	for k in st:
		if stats.has(k):
			stats[k] = st[k]
	var total := 0.0
	for b in balls:
		total += b.restoration
	g_target = total / balls.size()
	g_disp = g_target
	_resume_ball = clampi(int(world.get("ball", 0)), 0, balls.size() - 1)
	var b := balls[_resume_ball]
	player.place(b, b.surface_point(b.start_dir, 0.1))
	audio.set_ball(_resume_ball, false)
	aquarium.apply(g_disp)
	_resume_position()


## Places Gill where a continued run resumes: the last bloom on the ball the run was on (else
## that ball's arrival point). Blooms settle onto the ground on their first frame, so until the
## checkpoint bloom has, this waits (and no bloom is checked meanwhile).
func _resume_position() -> void:
	if _resume_ball < 0 or (checkpoint != null and not checkpoint.is_placed()):
		return
	var b := balls[_resume_ball]
	player.place(b, b.surface_point(b.start_dir, 0.1))
	var target := respawn_target()
	player.place(target[0], target[1])
	player.velocity = Vector3.ZERO
	cam.snap_behind()
	_last_pos = player.global_position
	_resume_ball = -1


func _capture_world() -> Dictionary:
	return {"ball": player.ball.index, "checkpoint": checkpoint.get_meta("completion_id", "") if checkpoint else "",
			"prompts_done": prompts_done.keys(), "tut_framed": _tut_framed, "all_clear_shown": all_clear_done,
			"stats": stats.duplicate(true)}


## Writes the run (clock, world, earned) now.
func save_run() -> bool:
	if run_save == null:
		return false
	run_save.run()["clock"] = clock.to_dict()
	run_save.run()["world"] = _capture_world()
	_save_dirty = false
	_autosave_t = 0.0
	return run_save.save()


## Reports a completion id. Each id counts once; returns true the first time.
func _earn(id: String) -> bool:
	if id == "" or run_save.earned().has(id):
		return false
	run_save.earned()[id] = snappedf(clock.play_s, 0.001)
	_save_dirty = true
	return true


func _on_restoration_changed(ball: MossBall) -> void:
	if not ball.completed:
		return
	_earn(Completion.ball_restored_id(ball.index))
	for b in balls:
		if not b.completed:
			return
	_finish_run()


## The game is finished: every moss ball fully restored. Freezes the run's finish time (once).
func _finish_run() -> void:
	if not clock.finish():
		return
	_earn(Completion.ENDING_ID)
	run_save.record_finish(clock.finish_s, completion.percent(run_save.earned()), Completion.CATALOG_VERSION, Boot.identity())
	save_run()


func completion_percent() -> float:
	return completion.percent(run_save.earned())


## One line for the title and pause menu: "Run 12:34.56 · 43% complete" (or the finish time).
func run_line() -> String:
	var pct := completion.percent_display(run_save.earned())
	if clock.is_finished():
		return "Finished in %s  ·  %d%% complete" % [RunClock.format(clock.finish_s), pct]
	return "Run time %s  ·  %d%% complete" % [RunClock.format(clock.run_s), pct]


func best_line() -> String:
	var best: float = run_save.records()["best_finish_s"]
	return "Best finish %s" % RunClock.format(best) if best >= 0.0 else ""


func _autosave(dt: float) -> void:
	_autosave_t += dt
	if (_save_dirty and _autosave_t > 1.0) or _autosave_t > 15.0:
		save_run()


func _notification(what: int) -> void:
	if clock == null:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			clock.suspend()
			save_run()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			clock.resume()
		NOTIFICATION_WM_CLOSE_REQUEST:
			save_run()


## Diagnostics section (shown through StartupTrace.timeline_text, the r5 bootstrap's hook).
func run_diagnostics_text() -> String:
	var L: Array[String] = []
	var e := run_save.earned()
	var rec := run_save.records()
	L.append("Run timer & completion")
	L.append("  Timer state: %s%s" % [clock.state, " (suspended)" if clock.suspended else ""])
	L.append("  Run time: %s  (%.3f s)" % [RunClock.format(clock.run_s), clock.run_s])
	L.append("  Play time incl. after finish: %s" % RunClock.format(clock.play_s))
	L.append("  Finished: %s" % ("yes, frozen at %s (%.3f s)" % [RunClock.format(clock.finish_s), clock.finish_s] if clock.is_finished() else "no"))
	L.append("  Best finish: %s" % (RunClock.format(rec["best_finish_s"]) if rec["best_finish_s"] >= 0.0 else "none yet"))
	L.append("  Completion: %.2f%%  (%d of %d catalog entries; %d earned ids stored)" % [completion.percent(e),
			completion.earned_known(e).size(), completion.size(), e.size()])
	L.append("  Run id: %s   started with catalog v%d; catalog now v%d" % [run_save.run()["id"],
			int(run_save.run()["catalog_version_at_start"]), Completion.CATALOG_VERSION])
	L.append("  Run save: %s, format %d, timer model %d; %s" % [run_save.path, RunSave.FORMAT, RunClock.TIMER_MODEL, run_save.origin])
	L.append("  Last save: %s" % run_save.last_save_result)
	return "\n".join(L)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state == "play":
		pause_menu.open()


func tank_flow() -> Vector3:
	return Vector3(1.2, 0.35, 0.4)


# --- Main loop ---------------------------------------------------------------------------

func _process(dt: float) -> void:
	_resume_position()
	clock.tick(dt, state == "play")
	if state == "play":
		_autosave(dt)
	if state == "title":
		_title_t += dt
		var up := player.up
		var right := player.facing.cross(up)
		var a := _title_t * 0.12
		var off := (player.facing * cos(a) + right * sin(a)) * 5.5 + up * 2.2
		cam.cine_pos = player.global_position + off
		cam.cine_look = player.global_position + up * 0.4
		cam.cine_up = up
		return

	if cinematic != "":
		_update_cinematic(dt)
	else:
		_check_blooms()
		_check_vortex_entry()
		_update_tutorial(dt)
	_check_vortex_connections()
	_update_restoration(dt)
	_update_mote_lights()
	_update_food(dt)
	_update_all_clear(dt)


func _update_restoration(dt: float) -> void:
	var total := 0.0
	for i in balls.size():
		total += balls[i].restoration
		ball_disp[i] = move_toward(ball_disp[i], balls[i].restoration, dt * 0.05)
	g_target = total / balls.size()
	# Continuous, gradual: tiny actions make tiny changes, never tiers.
	g_disp = move_toward(g_disp, g_target, dt * 0.012)
	aquarium.apply(g_disp)
	audio.update_mix(ball_disp, g_disp, player.ball.index)


func _update_all_clear(dt: float) -> void:
	if all_clear_done:
		return
	var done := true
	for b in balls:
		if not b.completed:
			done = false
	if not done:
		return
	if g_disp >= 0.999:
		if _all_clear_wait < 0.0:
			_all_clear_wait = 0.0
		_all_clear_wait += dt
		# A quiet period to notice the restored aquarium before the message.
		if _all_clear_wait > 12.0:
			all_clear_done = true
			hud.show_all_clear("Finished in %s  ·  %d%% complete" % [RunClock.format(clock.finish_s), completion.percent_display(run_save.earned())]
					if clock.is_finished() else "")
			save_run()
			Sfx.play("all_clear", null, -6.0)
			all_clear.emit()


# --- Combat ------------------------------------------------------------------------------

const SWIPE_REACH := 1.95
## The sweep covers 270 degrees: everything except a 90-degree cone straight ahead.
const SWIPE_FRONT_DOT := 0.7071
## The feeding lunge homes in on food within this range and cone, and catches it within the radius.
## It rises at most LUNGE_AIM_ABOVE, kept below the jump's height: the lunge never out-jumps the jump.
const LUNGE_CATCH_RADIUS := 0.95
const LUNGE_AIM_RANGE := 3.5
const LUNGE_AIM_ABOVE := 1.5
const LUNGE_AIM_BELOW := 1.5
const LUNGE_AIM_CONE := deg_to_rad(65.0)
## Aim assist turns the body at most this far so the nearest parasite sits inside the arc.
const SWIPE_AIM_MAX := deg_to_rad(60.0)
const SWIPE_AIM_TARGET := deg_to_rad(80.0)


## Everything on the axolotl's ball the tail swipe and hard landings can strike: live parasites and
## creatures that can be hit (Critter.hittable).
func _strikeable(p: Axolotl) -> Array:
	var out := []
	for par in p.ball.parasites:
		if par.is_alive():
			out.append(par)
	for c in p.ball.critters:
		if c.active and c.hittable():
			out.append(c)
	return out


## Flattened offset from the swiping axolotl to a parasite or creature, or ZERO when out of reach.
func _swipe_offset(p: Axolotl, par: Node3D) -> Vector3:
	var c := p.body_center()
	var to: Vector3 = par.closest_body_point(c) - c
	if to.length() > SWIPE_REACH + par.body_extent() or absf(to.dot(p.up)) > 1.5:
		return Vector3.ZERO
	var flat := to - p.up * to.dot(p.up)
	return flat if flat.length() > 0.001 else p.facing * 0.001


## Facing the swipe should turn toward so the nearest parasite in reach falls inside the
## arc (part-way turn, never more than SWIPE_AIM_MAX). ZERO when no turn is needed.
func swipe_aim(p: Axolotl) -> Vector3:
	var best := Vector3.ZERO
	var bd := INF
	for par in _strikeable(p):
		# (Aim assist never turns him toward a pufferfish: swiping one only bats it away.)
		if par is Pufferfish:
			continue
		var flat := _swipe_offset(p, par)
		if flat != Vector3.ZERO and flat.length() < bd:
			bd = flat.length()
			best = flat
	if best == Vector3.ZERO:
		return Vector3.ZERO
	var ang := p.facing.angle_to(best)
	if ang >= SWIPE_AIM_TARGET:
		return Vector3.ZERO
	var side := signf(p.facing.cross(best).dot(p.up))
	if side == 0.0:
		side = 1.0
	# Turn away from the parasite so the tail sweeps across it.
	return p.facing.rotated(p.up, -side * minf(SWIPE_AIM_TARGET - ang, SWIPE_AIM_MAX))


func player_swipe(p: Axolotl) -> void:
	var connected := false
	for par in _strikeable(p):
		var flat := _swipe_offset(p, par)
		if flat == Vector3.ZERO:
			continue
		# 270-degree sweep behind and beside; only a narrow cone straight ahead is safe.
		if flat.length() > 0.35 and flat.normalized().dot(p.facing) > SWIPE_FRONT_DOT:
			continue
		if par.hit(1, p.global_position):
			connected = true
	if connected:
		Settings.haptic("tap")
		Sfx.play("swipe_hit", p.global_position)
	else:
		Sfx.play("swipe", p.global_position, -3.0)


func pressure_wave(p: Axolotl, pos: Vector3, radius: float, stages: int) -> void:
	var hit := false
	for par in _strikeable(p):
		var cp: Vector3 = par.closest_body_point(pos)
		if cp.distance_to(pos) > radius + par.body_extent():
			continue
		if par is Critter:
			hit = par.hit(stages, pos) or hit
			continue
		var s := stages
		if par.kind == Parasite.Kind.SMALL:
			s = par.hp
		if par.hit(s, pos, 1.3):
			hit = true
	if hit:
		Settings.haptic("tap")
	if radius > 4.0:
		stats["extreme_landings"] += 1
	else:
		stats["hard_landings"] += 1


## Food the lunge homes in on: the nearest catchable food roughly ahead (within LUNGE_AIM_CONE of
## [param dir]), up to LUNGE_AIM_RANGE away along the ground and a little above or below.
func lunge_target(p: Axolotl, dir: Vector3) -> Food:
	var best: Food = null
	var bd := INF
	var chest := p.body_center()
	for f: Food in p.ball.foods:
		if not is_instance_valid(f) or not f.is_catchable():
			continue
		var d := f.catch_point() - chest
		var vert := d.dot(p.up)
		var flat := d - p.up * vert
		if flat.length() > LUNGE_AIM_RANGE or vert > LUNGE_AIM_ABOVE or vert < -LUNGE_AIM_BELOW:
			continue
		if flat.length() > 0.3 and dir.angle_to(flat) > LUNGE_AIM_CONE:
			continue
		if d.length() < bd:
			bd = d.length()
			best = f
	return best


func lunge_contact(p: Axolotl) -> bool:
	var head := p.head_position()
	var chest := p.body_center()
	var tip := head + p.facing * 0.2
	for f in p.ball.foods.duplicate():
		if not is_instance_valid(f) or not f.is_catchable():
			continue
		if _seg_dist(f.catch_point(), chest, tip) < LUNGE_CATCH_RADIUS:
			_eat(p, f)
			return true
	for m in p.ball.motes:
		if m.is_available() and _seg_dist(m.global_position, chest, tip) < 0.9:
			m.capture()
			Settings.haptic("mote")
			Sfx.play("mote_capture", m.global_position)
			_hide_prompt("lunge", true)
			return true
	return false


func _seg_dist(pt: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var k := clampf((pt - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return pt.distance_to(a + ab * k)


func lunge_miss(p: Axolotl) -> void:
	var head := p.head_position()
	WaterFX.inst.impulse(head, 1.4, 0.4)
	for m in p.ball.motes:
		if not m.is_available():
			continue
		var d: Vector3 = m.global_position - head
		var dist := d.length()
		if dist < 3.0:
			var dir := (d + p.facing * 0.6).normalized()
			m.push(dir * 5.5 / (1.0 + dist * 0.6))
	Sfx.play("lunge", p.global_position, -4.0)


func _eat(p: Axolotl, f: Food) -> void:
	var amount := f.heal_amount(p.max_health)
	p.heal(amount)
	stats["eaten"][f.type] += 1
	WaterFX.inst.sparkle(f.catch_point(), Color(1.0, 0.8, 0.6, 0.8), 8, 1.0, 0.05, 0.6)
	Sfx.play("eat_big" if f.type == Food.Type.BURROWER else "eat", p.global_position)
	p.model.happy_t = 0.0 if f.type == Food.Type.BURROWER else p.model.happy_t
	p.ball.foods.erase(f)
	f.eaten()
	_hide_prompt("lunge", true)


func parasite_killed(par: Parasite) -> void:
	stats["kills"] += 1
	_earn(par.get_meta("completion_id", ""))
	var ball := par.ball
	# Stolen vitality returns to the moss.
	WaterFX.inst.sparkle(par.global_position, Color(0.45, 1.0, 0.45, 0.9), 22, 2.2, 0.08, 1.2)
	Sfx.play("drain", par.global_position)
	ball.complete_event(par.zone_id, par.global_position, 12.0)
	_hide_prompt("swipe", true)


## A creature defeated by the axolotl (crab guardians and cave eels are completion entries).
func critter_defeated(c: Critter) -> void:
	stats["critters"] = int(stats.get("critters", 0)) + 1
	_earn(c.threat_id)
	WaterFX.inst.sparkle(c.global_position, Color(0.85, 1.0, 0.8, 0.9), 16, 1.8, 0.07, 1.0)
	Sfx.play("drain", c.global_position, -4.0)


func species_known(sp: String) -> bool:
	return run_save != null and run_save.earned().has("species." + sp)


## The first close look at a species (once per run).
func discover_species(sp: String) -> void:
	if _earn("species." + sp):
		hud.show_discovery("New species: %s" % Ecosystem.SPECIES.get(sp, sp))
		Sfx.play("discover", null, -4.0)


func mote_restored(m: Mote) -> void:
	stats["motes"] += 1
	_earn(m.get_meta("completion_id", ""))
	WaterFX.inst.sparkle(m.global_position, Color(0.5, 1.0, 0.7, 0.9), 18, 1.6, 0.07, 1.2)
	Sfx.play("restore", m.global_position)
	m.ball.complete_event(m.zone_id, m.global_position, 11.0)


func upgrade_collected(u: Node) -> void:
	stats["upgrades"] += 1
	_earn(u.get_meta("completion_id", ""))
	if u.get("kind") == "pearl":
		player.restore_full()
	else:
		player.add_max_health()
	player.model.happy_t = 0.0
	WaterFX.inst.sparkle(player.body_center(), Color(0.4, 1.0, 0.9, 1.0), 30, 2.0, 0.08, 1.4)
	Sfx.play("upgrade", player.global_position)
	Settings.haptic("heavy")


func on_water_impulse(pos: Vector3, strength: float) -> void:
	if player == null or player.ball == null:
		return
	for par in player.ball.parasites:
		if par.is_alive():
			var d: Vector3 = par.global_position - pos
			if d.length() < 2.0:
				par.water_push(d.normalized() * strength * 0.8)


func _on_event_restored(ball: MossBall, pos: Vector3) -> void:
	restoration_event.emit(ball.index)
	for v in ball.vortices:
		if v.ball_a == ball and not v.connected:
			v.pulse()
	if player.ball == ball and player.global_position.distance_to(pos) < 10.0:
		player.model.happy_t = 0.0
	Settings.haptic("mote")


func _on_zone_completed(ball: MossBall, zone_id: String) -> void:
	Sfx.play("zone_bloom", player.global_position, -4.0)
	if ball.index == 0 and zone_id == "tut" and not _tut_framed:
		_tut_framed = true
		get_tree().create_timer(1.3).timeout.connect(func(): _start_cinematic("frame", {}))


# --- Checkpoints / regeneration ----------------------------------------------------------

func _check_blooms() -> void:
	if player.state != "normal" or _resume_ball >= 0:
		return
	for bl in player.ball.blooms:
		if not bl.is_placed():
			continue
		if bl.global_position.distance_to(player.body_center()) < 1.35:
			if checkpoint != bl:
				bl.activate()
				checkpoint = bl
				_earn(bl.get_meta("completion_id", ""))
				save_run()
				Settings.haptic("tap")


func respawn_target() -> Array:
	if checkpoint and checkpoint.ball == player.ball:
		return [checkpoint.ball, checkpoint.respawn_point(), checkpoint]
	var b := player.ball
	if b.index == 0 and checkpoint == null:
		return [b, b.surface_point(b.start_dir, 0.2), null]
	if b.vortex_in:
		var d: Vector3 = b.vortex_in.dir_b
		var off := d.rotated(MossBall.frame_at(d, 0).x, deg_to_rad(6.0))
		return [b, b.surface_point(off, 0.3), null]
	return [checkpoint.ball, checkpoint.respawn_point(), checkpoint]


func _on_player_died() -> void:
	stats["deaths"] += 1
	_start_cinematic("regen", {})


# --- Vortex ------------------------------------------------------------------------------

func _check_vortex_connections() -> void:
	for v in vortices:
		if not v.connected and v.ball_a.restoration >= Vortex.CONNECT_AT - 0.0001:
			v.connected = true
			stats["connects"].append(v.ball_a.index)
			_earn(v.get_meta("completion_id", ""))
			_pending_connect.append(v)
	# The connection shot waits for any running cinematic (e.g. regeneration) to finish.
	if not _pending_connect.is_empty() and cinematic == "" and player.state == "normal":
		_start_cinematic("connect", {"v": _pending_connect.pop_front()})


func _check_vortex_entry() -> void:
	player.ext_vel = Vector3.ZERO
	if player.state != "normal":
		return
	for v in vortices:
		if not v.connected:
			continue
		for at_b in [false, true]:
			var mb: MossBall = v.ball_b if at_b else v.ball_a
			if mb != player.ball:
				continue
			var to: Vector3 = v.mouth_pos(at_b) - player.body_center()
			var flat := to - player.up * to.dot(player.up)
			if _vortex_block == v:
				if flat.length() > 4.5:
					_vortex_block = null
				continue
			# An open whirlpool gently draws an axolotl that is swimming toward it (never one
			# that is just busy nearby).
			var toward := player.velocity.dot(flat.normalized())
			if flat.length() < 3.8 and toward > 1.5:
				var k := 1.0 - flat.length() / 3.8
				player.ext_vel = flat.normalized() * 2.0 * k
			if flat.length() < 2.0 and absf(to.dot(player.up)) < 2.5:
				_start_cinematic("travel", {"v": v, "reverse": at_b})
				return


# --- Cinematics --------------------------------------------------------------------------

func _start_cinematic(kind: String, data: Dictionary) -> void:
	cinematic = kind
	cine_t = 0.0
	cine_data = data
	player.controls_enabled = false
	hud.set_cinematic(true)
	match kind:
		"frame":
			cam.cinematic = true
		"connect":
			cam.cinematic = true
			Sfx.play("vortex_connect", null, -3.0)
			Settings.haptic("vortex")
			player.velocity = Vector3.ZERO
		"travel":
			player.state = "cinematic"
			player.velocity = Vector3.ZERO
			cam.cinematic = true
			Sfx.play("vortex_enter", player.global_position)
			audio.travel_whoosh(true)
		"regen":
			player.state = "dead"
			_regen_from = player.global_position
			cam.cinematic = true
			Sfx.play("dissolve", player.global_position)


func _end_cinematic() -> void:
	cinematic = ""
	cam.cinematic = false
	player.controls_enabled = state == "play"
	hud.set_cinematic(false)


func _update_cinematic(dt: float) -> void:
	cine_t += dt
	match cinematic:
		"frame": _cine_frame()
		"connect": _cine_connect()
		"travel": _cine_travel(dt)
		"regen": _cine_regen()


func _cine_frame() -> void:
	# After the first local restoration: pull back to reveal the still-sick moss ball.
	var b := player.ball
	var up := player.up
	var side := player.facing
	var d := (up * 0.55 - side * 0.85).normalized()
	cam.cine_pos = b.global_position + d * (b.radius + 30.0)
	cam.cine_look = b.global_position + up * b.radius * 0.25
	cam.cine_up = (up - d * up.dot(d)).normalized()
	if cine_t > 3.8:
		_end_cinematic()
		get_tree().create_timer(1.0).timeout.connect(func(): _show_prompt("camera"))


func _cine_connect() -> void:
	var v: Vortex = cine_data["v"]
	var k := clampf(cine_t / 4.6, 0.0, 1.0)
	var a := v.mouth_pos(false)
	var side := v.dir_a.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var look: Vector3 = v.sample(0.05 + 0.9 * smoothstep(0.0, 0.8, k))[0]
	cam.cine_pos = a + v.dir_a * 7.0 + side * 9.0 + (look - a) * 0.25
	cam.cine_look = look
	cam.cine_up = v.dir_a.cross(side).normalized() * -1.0 if false else (Vector3.UP - v.dir_a * Vector3.UP.dot(v.dir_a)).normalized()
	if cine_t > 4.8:
		_end_cinematic()


func _cine_travel(dt: float) -> void:
	var v: Vortex = cine_data["v"]
	var rev: bool = cine_data["reverse"]
	var dur := 6.0
	var k := clampf(cine_t / dur, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var t := 1.0 - e if rev else e
	var s: Array = v.sample(t)
	var fwd: Vector3 = s[1] * (-1.0 if rev else 1.0)
	var u: Vector3 = s[2]
	var side := fwd.cross(u).normalized()
	u = side.cross(fwd).normalized()
	# Surf the spiral: orbit inside the tube and bank into the turns.
	var phi := k * TAU * 2.2
	var bank := sin(phi) * 0.8
	var r := 0.9 * sin(k * PI)
	var pos: Vector3 = s[0] + (u * cos(phi) + side * sin(phi)) * r
	var surf_up := u.rotated(fwd, bank)
	player.global_position = pos
	player.global_basis = Basis(fwd.cross(surf_up).normalized(), surf_up, -fwd).orthonormalized()
	player.model.surf = 1.0
	player.model.surf_bank = bank * 0.6
	player.model.grounded = false
	player.model.speed = 1.3
	if randf() < 0.6:
		WaterFX.inst._spawn_puff(pos + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 3.0, -fwd * 12.0, 0.4, 0.06, Color(0.8, 0.95, 1.0, 0.6), 0.5)
	# Camera: pull back as it grabs him, follow, move alongside, then ahead to see his face.
	var cp: Vector3
	var look := pos
	if k < 0.15:
		cp = pos - fwd * 3.0 + surf_up * 2.5 + side * 1.5
	elif k < 0.5:
		cp = pos - fwd * 3.5 + surf_up * 1.0
	elif k < 0.72:
		cp = pos + side * 2.6 + surf_up * 0.6 - fwd * 0.5
	elif k < 0.9:
		cp = pos + fwd * 2.6 + surf_up * 0.5
	else:
		cp = pos - fwd * 3.5 + surf_up * 1.5
	cam.cine_pos = cam.cine_pos.lerp(cp, minf(1.0, dt * 4.0)) if cine_t > 0.05 else cp
	cam.cine_look = look
	cam.cine_up = surf_up
	if k >= 1.0:
		var dest: MossBall = v.ball_a if rev else v.ball_b
		var ddir: Vector3 = v.dir_a if rev else v.dir_b
		var tang := MossBall.frame_at(ddir, 0).x
		var out_dir := ddir.rotated(tang, deg_to_rad(5.5))
		player.state = "normal"
		player.model.surf = 0.0
		player.place(dest, dest.surface_point(out_dir, 1.2), (dest.surface_point(out_dir) - dest.surface_point(ddir)))
		player.velocity = dest.up_at(player.global_position) * 3.0
		player.grounded = false
		_vortex_block = v
		stats["travels"].append([v.ball_a.index, rev])
		audio.set_ball(dest.index, true)
		audio.travel_whoosh(false)
		Sfx.play("vortex_exit", player.global_position)
		cam.snap_behind()
		_end_cinematic()


func _cine_regen() -> void:
	# Dissolve into bioluminescent particles that travel back to the last bloom and reform.
	var target := respawn_target()
	var dest_pos: Vector3 = target[1]
	if cine_t < 0.8:
		player.model.dissolve = cine_t / 0.8
		if int(cine_t * 30.0) % 3 == 0:
			WaterFX.inst.sparkle(player.body_center(), Color(0.45, 1.0, 0.85, 0.9), 4, 1.2, 0.07, 0.8)
		cam.cine_pos = _regen_from + player.up * 3.0 - player.facing * 4.0
		cam.cine_look = _regen_from
		cam.cine_up = player.up
	elif not cine_data.has("wisp"):
		cine_data["wisp"] = true
		var travel := clampf(_regen_from.distance_to(dest_pos) / 25.0, 0.8, 1.6)
		cine_data["travel"] = travel
		WaterFX.inst.wisp(player.body_center(), dest_pos, travel, Color(0.45, 1.0, 0.85, 0.95), 40)
	elif cine_t < 0.8 + float(cine_data["travel"]):
		var k := (cine_t - 0.8) / float(cine_data["travel"])
		var p := _regen_from.lerp(dest_pos, k)
		var b: MossBall = target[0]
		var up := b.up_at(p)
		cam.cine_pos = p + up * 5.0 + (dest_pos - _regen_from).normalized() * -5.0
		cam.cine_look = p
		cam.cine_up = up
	elif not cine_data.has("placed"):
		cine_data["placed"] = true
		var b: MossBall = target[0]
		player.place(b, dest_pos)
		if target[2]:
			(target[2] as Bloom).brighten()
		audio.set_ball(b.index, true)
		Sfx.play("reform", dest_pos)
		cine_data["t_placed"] = cine_t
	else:
		var k := clampf((cine_t - float(cine_data["t_placed"])) / 0.7, 0.0, 1.0)
		player.model.dissolve = 1.0 - k
		var up := player.up
		cam.cine_pos = player.global_position + up * 2.0 - player.facing * 4.0
		cam.cine_look = player.global_position + up * 0.3
		cam.cine_up = up
		if k >= 1.0:
			player.state = "normal"
			player.restore_full()
			player.invuln_t = 1.5
			cam.snap_behind()
			_end_cinematic()


# --- Motes' light -------------------------------------------------------------------------

func _update_mote_lights() -> void:
	var ref := cam.global_position
	var list := []
	for m in player.ball.motes:
		if m.state == "wander" or m.state == "captured":
			list.append([m.global_position.distance_squared_to(ref), m])
	list.sort_custom(func(a, b): return a[0] < b[0])
	var arr := PackedVector4Array()
	arr.resize(6)
	var n := mini(6, list.size())
	for i in n:
		var m: Mote = list[i][1]
		arr[i] = Vector4(m.global_position.x, m.global_position.y, m.global_position.z, m.intensity * 0.55)
	WaterFX.inst.mote_uniform = arr
	WaterFX.inst.mote_count = n
	var lights := quality.mote_lights if quality else 3
	for i in _mote_lights.size():
		var l := _mote_lights[i]
		if i < mini(lights, list.size()) and list[i][0] < 900.0:
			var m: Mote = list[i][1]
			l.global_position = m.global_position
			l.light_energy = 0.9 * m.intensity
			l.visible = true
		else:
			l.visible = false


# --- Food ---------------------------------------------------------------------------------

func _initial_food(b: MossBall) -> void:
	for i in b.food_target:
		_spawn_food(b, true)


func _update_food(dt: float) -> void:
	_food_timer -= dt
	if _food_timer > 0.0:
		return
	_food_timer = 2.5
	var b := player.ball
	b.foods = b.foods.filter(func(f): return is_instance_valid(f))
	if b.foods.size() < b.food_target:
		_spawn_food(b, false)


func _pick_type(b: MossBall) -> int:
	var r := randf()
	var w: Array = b.food_weights
	if r < w[0]:
		return Food.Type.DRIFTER
	if r < w[0] + w[1]:
		return Food.Type.DARTER
	return Food.Type.BURROWER


func _spawn_food(b: MossBall, initial: bool) -> void:
	var t := _pick_type(b)
	var pdir := b.up_at(player.global_position) if player and player.ball == b else Vector3.ZERO
	if t == Food.Type.BURROWER:
		var free := b.food_spots.filter(func(h): return not h["occupied"] and (pdir == Vector3.ZERO or initial or (h["dir"] as Vector3).angle_to(pdir) > deg_to_rad(10)))
		if free.is_empty():
			t = Food.Type.DRIFTER
		else:
			var f := Food.new()
			f.setup_burrower(b, free[randi() % free.size()])
			b.add_child(f)
			b.foods.append(f)
			return
	if b.food_regions.is_empty():
		return
	var reg: Dictionary = b.food_regions[randi() % b.food_regions.size()]
	var rd: Vector3 = reg["dir"]
	for attempt in 8:
		var dir := rd.rotated(MossBall.frame_at(rd, randf() * 360.0).x, deg_to_rad(randf() * float(reg["radius"]) * 0.8))
		# New organisms arrive out of view: they drift or swim in from open water.
		if not initial and pdir != Vector3.ZERO and dir.angle_to(pdir) < deg_to_rad(22):
			continue
		var h := randf_range(0.8, 1.8) if initial else randf_range(7.0, 10.0)
		var f := Food.new()
		f.setup(b, t, b.surface_point(dir, h), rd, float(reg["radius"]))
		if initial:
			f.state = "idle"
		b.add_child(f)
		b.foods.append(f)
		return


# --- Tutorial prompts ---------------------------------------------------------------------

func _show_prompt(name_: String) -> void:
	if prompts_done.has(name_) or prompts_active.has(name_):
		return
	prompts_active[name_] = true
	hud.show_prompt(name_)


func _hide_prompt(name_: String, done: bool) -> void:
	if done:
		prompts_done[name_] = true
	if prompts_active.has(name_):
		prompts_active.erase(name_)
		hud.hide_prompt(name_)


func _update_tutorial(_dt: float) -> void:
	if state != "play":
		return
	_moved += player.global_position.distance_to(_last_pos)
	_last_pos = player.global_position
	if _moved > 2.0:
		_hide_prompt("move", true)
	var b := player.ball
	if b.index == 0 and not prompts_done.has("jump"):
		var m1 := b.surface_point(MossBall.dir_ll(79, 0))
		if player.global_position.distance_to(m1) < 4.8 and player.grounded:
			_show_prompt("jump")
	if not prompts_done.has("burst") and prompts_done.has("jump"):
		var m1 := balls[0].surface_point(MossBall.dir_ll(79, 0), 1.3)
		if b.index == 0 and player.global_position.distance_to(m1) < 2.6:
			_show_prompt("burst")
	if not prompts_done.has("swipe"):
		for par in b.parasites:
			if par.is_alive() and par.global_position.distance_to(player.global_position) < 5.0:
				_show_prompt("swipe")
				break
	if not prompts_done.has("lunge"):
		for m in b.motes:
			if m.is_available() and m.global_position.distance_to(player.global_position) < 4.5:
				_show_prompt("lunge")
				break
		for f in b.foods:
			if is_instance_valid(f) and f.is_catchable() and f.catch_point().distance_to(player.global_position) < 4.0:
				_show_prompt("lunge")
				break


func notify_action(action: String) -> void:
	match action:
		"jump": _hide_prompt("jump", true)
		"burst": _hide_prompt("burst", true)
		"camera": _hide_prompt("camera", true)
