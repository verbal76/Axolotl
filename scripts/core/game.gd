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
## Runs the equipped Tier-2 ability when its button is pressed.
var t2: Tier2Combat
## Expansion 5's creatures: placement, activation near the axolotl, discovery (docs/ECOSYSTEM.md).
var ecosystem: Ecosystem
## The decorative aquarium fish (noncombatants; docs/AQUARIUM.md).
var fish: AmbientFish
var balls: Array[MossBall] = []
var vortices: Array[Vortex] = []
var player: Axolotl
var cam: FollowCam
var hud: Hud
var title: TitleScreen
var pause_menu: PauseMenu
var quality: QualityScaler
## The aquarium experiences (docs/AQUARIUM.md): the room, inspection, Live Tank and Swim Mode.
var presentation: Presentation
## Treasure Hunt, the postgame search (docs/TREASURE_HUNT.md).
var treasure: TreasurePlay
## Permanent progression (docs/SKILL_TREE.md): red starfish collected and skills bought. Survives New
## Run (its own file); not in the completion catalog.
var gill: GillProgress
## The red starfish still in the world.
var starfish: StarfishField
## Onboarding (docs/ONBOARDING.md): the intro screen and the three first-discovery lessons.
var onboarding: Onboarding

var state := "title"          # title | play | aquarium (the experiences; the clock never counts)
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
## Food arrivals: local region targets and cooldowns, its own generator (FoodDirector).
var food: FoodDirector
## Parasites returning to cleared zones (Repopulation); Normal rules.
var repop: Repopulation
var _repop_t := 0.0
## Hard Mode's tug of war (HardMode; ledger row 12): null in a Normal run.
var hard: HardMode
var _hard_t := 0.0
var _vortex_block: Vortex = null
var _pending_connect: Array = []
var _moved := 0.0
var _last_pos := Vector3.ZERO
var _camera_moved := false
var _title_t := 0.0
var _regen_from := Vector3.ZERO
## Mote's loading screen, on top until the first usable frame has been drawn.
var loading: LoadingScreen
## Fully automatic OTA updates: the launch check and applying a downloaded update at a safe moment.
var auto_update: AutoUpdate
## The everyday About / Diagnostics page (the native recovery panel sits behind its Advanced).
var diagnostics: DiagnosticsPage
## Platform leaves' landing give and current sway (visual only).
var leaf_motion: LeafMotion
## Frame pacing on the title and in play (Diagnostics).
var frame_stats: FrameStats
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
## This run's Tier-2 abilities (unlocked, equipped, cooldown).
var tier2 := Tier2.new()
## Harmless practice targets a Tier-2 shrine sets out (PracticeTarget): struck like parasites.
var practice_targets: Array = []
var stats := {"kills": 0, "returner_kills": 0, "motes": 0, "eaten": [0, 0, 0], "upgrades": 0, "deaths": 0, "extreme_landings": 0, "hard_landings": 0,
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
	diagnostics = DiagnosticsPage.new()
	add_child(diagnostics)
	frame_stats = FrameStats.new()
	frame_stats.g = self
	add_child(frame_stats)
	auto_update = AutoUpdate.new()
	auto_update.g = self
	add_child(auto_update)
	await _drawn()
	StartupTrace.mark("first frame drawn: Mote loading screen visible")
	AutoUpdate.on_loading_visible()
	# Automatic updates: the channel is checked while the world builds; a verified update that is
	# ready in time (capped) takes over before the title appears.
	auto_update.begin_launch_check()
	await _build_world()
	_open_run()
	if await auto_update.launch_gate(loading):
		return
	process_mode = Node.PROCESS_MODE_INHERIT
	if Settings.test_mode != "":
		start_play(true)
	elif Settings.skip_title:
		begin_play(true)
	else:
		_enter_title()
	StartupTrace.mark("world ready (%s); first world frame requested" % state)
	await _drawn()
	StartupTrace.mark("first frame drawn: %s usable" % state)
	AutoUpdate.on_usable()
	loading_stages = loading.stages.duplicate()
	loading.finish()
	# (The colours page's pattern swatches, drawn off the main thread now that the game is up.)
	GillLook.warm_patterns()
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
	# AgX (Expansion 6): bright greens and the pink axolotl roll off softly instead of going neon;
	# a light grade keeps the tank natural rather than primary-coloured.
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.12
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.9
	env.adjustment_contrast = 1.06
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
	t2 = Tier2Combat.new()
	add_child(t2)
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
	for li in Levels.LINKS.size():
		var pair: Array = Levels.LINKS[li]
		var v := Vortex.new()
		v.tint = Vortex.TINTS[li % Vortex.TINTS.size()]
		v.link_index = li
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
	ecosystem = Ecosystem.new()
	add_child(ecosystem)
	ecosystem.populate(balls)
	fish = AmbientFish.new()
	fish.name = "AmbientFish"
	add_child(fish)
	fish.setup(Aquarium.TANK_MIN, Aquarium.TANK_MAX, balls)
	StartupTrace.mark("creatures placed")
	await _stage("Setting up the tank")

	hud = Hud.new()
	add_child(hud)
	StartupTrace.mark("HUD built")
	onboarding = Onboarding.new()
	onboarding.name = "Onboarding"
	onboarding.g = self
	add_child(onboarding)
	onboarding.ui = OnboardingUi.new()
	add_child(onboarding.ui)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	StartupTrace.mark("pause menu built")
	title = TitleScreen.new()
	add_child(title)
	quality = QualityScaler.new()
	add_child(quality)
	presentation = Presentation.new()
	presentation.g = self
	add_child(presentation)
	presentation.ui = PresentationUi.new()
	presentation.ui.p = presentation
	add_child(presentation.ui)
	treasure = TreasurePlay.new()
	treasure.g = self
	add_child(treasure)
	starfish = StarfishField.new()
	starfish.g = self
	add_child(starfish)
	# Android's back gesture is handled (the aquarium steps back out, play opens the menu).
	get_tree().quit_on_go_back = false

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
	_build_room_soon()


## The bedroom round the tank is built once, just after the title is usable (so it never lengthens
## startup), or on first need (Aquarium.ensure_room).
func _build_room_soon() -> void:
	if aquarium == null:
		return
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_instance_valid(aquarium):
			aquarium.ensure_room())


## Play (with no saved run) and New Run come here: every new run shows the intro screen first while
## tutorials are on (docs/ONBOARDING.md); a Continue never does.
func begin_play(immediate := false) -> void:
	if onboarding != null and onboarding.intro_due(has_run_in_progress()):
		state = "title"
		title.hide_title()
		hud.visible_controls(false)
		player.controls_enabled = false
		cam.cinematic = true
		onboarding.show_intro(func() -> void: start_play(immediate))
		Boot.report_ready()
		return
	start_play(immediate)


func start_play(immediate := false) -> void:
	var continuing := has_run_in_progress()
	_build_room_soon()
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
	if treasure != null:
		treasure.refresh()
	if onboarding != null:
		onboarding.on_play_started(continuing)
	Boot.report_ready()


## New Run: a fresh run (world, completion, clock) straight into play. Records such as the best
## finish time are kept. `mode` "hard" makes it a Hard Mode run (chosen here only; a Normal run never
## converts). A Normal run carries no mode key, exactly as before Hard Mode existed.
func restart_experience(mode := "normal") -> void:
	run_save.start_new_run()
	if mode == HardMode.MODE:
		run_save.run()["mode"] = HardMode.MODE
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
	tier2 = Tier2.from_dict(run_save.run().get("tier2", {}))
	# Food and repopulation hash from the run (food's first organisms too, so they wait for it).
	food = FoodDirector.new()
	food.setup(rng_key(), balls)
	for b in balls:
		food.initial(b)
	StartupTrace.mark("food placed")
	if leaf_motion == null:
		leaf_motion = LeafMotion.new()
		add_child(leaf_motion)
		leaf_motion.setup(self)
	# (Automated runs: --mode=hard makes the fresh test run a Hard Mode run.)
	if Settings.test_mode != "" and str(Settings.test_args.get("mode", "")) == HardMode.MODE and not has_run_in_progress():
		run_save.run()["mode"] = HardMode.MODE
	if is_hard():
		hard = HardMode.new()
		hard.key = rng_key()
		var hr := HardMode.hard_rules()
		hr.hard_ref = weakref(hard)
		repop = Repopulation.new(hr)
		hard.owe_fn = repop.owe
		hard.can_return_fn = func(zk: String) -> bool: return not (repop.zones.get(zk, {}).get("eligible", []) as Array).is_empty()
	else:
		repop = Repopulation.new(Repopulation.normal_rules())
	repop.key = rng_key()
	repop.build(balls, vortices)
	repop.from_dict((run_save.run().get("world", {}) as Dictionary).get("repop", {}))
	_open_gill()
	_apply_run()
	if hard != null:
		hard.build(balls, vortices)
		hard.from_dict((run_save.run().get("world", {}) as Dictionary).get("vitality", {}))
		hard.paint_all()
		hard.living_aquarium.connect(_on_living_aquarium)
		hud.show_vitality(true)
	StartupTrace.mark("run save opened (%s)" % run_save.origin.get_slice(" (", 0))


static func gill_progress_path() -> String:
	if Settings.test_args.has("gill-save"):
		return Settings.test_args["gill-save"]
	# Automated runs never touch the player's progress.
	return "user://test_gill_progress.json" if Settings.test_mode != "" else GillProgress.PATH


## The key food and repopulation hash from: the run id (a fixed key in seeded test runs, so a
## seed always plays out the same way).
func rng_key() -> String:
	if Settings.test_mode != "":
		return "test-%s" % str(Settings.test_args.get("seed", "4242"))
	return str(run_save.run()["id"])


## Opens the permanent progression and gives him its skills. Tests start from none unless given a
## file, and may grant skills with --skills=all or --skills=<id>,<id> (every starfish collected too).
func _open_gill() -> void:
	var path := gill_progress_path()
	if Settings.test_mode != "" and not Settings.test_args.has("gill-save"):
		GillProgress.erase(path)
	gill = GillProgress.open(path)
	var grant := str(Settings.test_args.get("skills", "")) if Settings.test_mode != "" else ""
	if grant != "":
		grant_skills(SkillTree.ids() if grant == "all" else Array(grant.split(",", false)))
	player.apply_skills(gill.tiers())
	_setup_onboarding()
	StartupTrace.mark("progress opened (%s)" % gill.origin.get_slice(";", 0))


## Onboarding's per-run record (docs/ONBOARDING.md, ruling of 2026-10-01: once per run). A run not
## yet started (Play with no saved run, or New Run) gets a fresh one: its lessons are to come. A run
## in progress keeps its own; one saved before the record existed has none and counts every lesson
## as done (no lesson mid-run, no frond emptied; the next new run plays them). The profile's old
## onboarding keys are kept as they are and no longer read. Automated runs: --onboarding=done (the
## default for unit tests, renders and probes: every lesson done, so nothing else changes) or
## --onboarding=fresh (the playthrough's default: a new run's lessons, the bots dismiss the cards)
## or --onboarding=player (exactly what a player's launch does with the run save it is given).
func _setup_onboarding() -> void:
	if Settings.test_mode != "":
		var mode := str(Settings.test_args.get("onboarding", "fresh" if Settings.test_mode == "playthrough" else "done"))
		if mode == "done":
			onboarding.record_all_done()
			return
		if mode == "fresh":
			onboarding.record_for_new_run()
			return
	if not has_run_in_progress():
		onboarding.record_for_new_run()
	elif not run_save.has_lessons():
		onboarding.record_all_done()


## Tests and renders only: every starfish collected and these nodes bought (prerequisites ignored).
func grant_skills(ids: Array) -> void:
	for sid in StarfishTable.ids():
		gill.collected[sid] = {"t": 0, "v": "test"}
	for id in ids:
		if SkillTree.has(str(id)):
			gill.purchased[str(id)] = {"cost": SkillTree.cost(str(id)), "t": 0, "n": gill.purchased.size() + 1}
	gill.save()
	player.apply_skills(gill.tiers())


## Buys a skill-tree node (the page calls this): "" when bought, else why not. Applies at once.
func buy_skill(id: String) -> String:
	var why := gill.buy(id)
	if why == "":
		player.apply_skills(gill.tiers())
	return why


## "Red Starfish 12/30  ·  Skills 4/15" (pause menu, title, records).
func progress_line() -> String:
	if gill == null:
		return ""
	return "Red Starfish %d/%d  ·  Skills %d/%d" % [gill.stars(), StarfishTable.COUNT, gill.skills(), SkillTree.COUNT]


## Whether this run is a Hard Mode run (chosen at New Run; missing = Normal, so every older save is Normal).
func is_hard() -> bool:
	return run_save != null and str(run_save.run().get("mode", "normal")) == HardMode.MODE


## True when there is a run to continue (the title then offers Continue and New Run).
func has_run_in_progress() -> bool:
	return clock.state != "not_started" or not run_save.earned().is_empty()


## Restores a saved run's world: everything earned is put back silently (no effects, no signals),
## then Gill is placed at the last bloom on the ball the run was on.
func _apply_run() -> void:
	var e := run_save.earned()
	var world: Dictionary = run_save.run().get("world", {})
	for b in balls:
		for s in b.shrines:
			s.set_taken(tier2.has(s.ability))
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
			"stats": stats.duplicate(true), "repop": repop.to_dict() if repop != null else {}}.merged(
			{"vitality": hard.to_dict()} if hard != null else {})


## Writes the run (clock, world, earned) now.
func save_run() -> bool:
	if run_save == null:
		return false
	run_save.run()["clock"] = clock.to_dict()
	run_save.run()["world"] = _capture_world()
	run_save.run()["tier2"] = tier2.to_dict()
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
	run_save.record_finish(clock.finish_s, completion.percent(run_save.earned()), Completion.CATALOG_VERSION, Boot.identity(), gill.skills() if gill else 0,
			HardMode.MODE if hard != null else "")
	save_run()


func completion_percent() -> float:
	return completion.percent(run_save.earned())


## One line for the title and pause menu: "Run 12:34.56 · 43% complete" (or the finish time).
## A Hard Mode run says so first ("Hard Mode  ·  Run time ...").
func run_line() -> String:
	var pct := completion.percent_display(run_save.earned())
	var pre := "Hard Mode  ·  " if is_hard() else ""
	if clock.is_finished():
		return pre + "Finished in %s  ·  %d%% complete  ·  Skills %d/%d" % [RunClock.format(clock.finish_s), pct, finish_skills(), SkillTree.COUNT]
	return pre + "Run time %s  ·  %d%% complete" % [RunClock.format(clock.run_s), pct]


## Skills owned when this run finished (its record), or now for an older record without it.
func finish_skills() -> int:
	var f: Dictionary = run_save.run().get("finish", {})
	if f.has("skills"):
		return int(f["skills"])
	return gill.skills() if gill else 0


## The best Normal finish, then the best Hard Mode finish when there is one (kept apart).
func best_line() -> String:
	var normal := _best_normal_line()
	var hb := float(run_save.records().get("best_finish_s_hard", -1.0))
	if hb < 0.0:
		return normal
	var hard_part := "Best Hard Mode finish %s" % RunClock.format(hb)
	return hard_part if normal == "" else normal + "  ·  " + hard_part


func _best_normal_line() -> String:
	var rec := run_save.records()
	var best: float = rec["best_finish_s"]
	if best < 0.0:
		return ""
	# (With the skills it was finished with, when the record has them: there is no skills-off mode.)
	for f in rec.get("finishes", []):
		if f is Dictionary and str(f.get("run_id", "")) == str(rec.get("best_run_id", "")) and absf(float(f.get("finish_s", -1.0)) - best) < 0.001 \
				and (f as Dictionary).has("skills"):
			return "Best finish %s  ·  Skills %d/%d" % [RunClock.format(best), int(f["skills"]), SkillTree.COUNT]
	return "Best finish %s" % RunClock.format(best)


func _autosave(dt: float) -> void:
	_autosave_t += dt
	if (_save_dirty and _autosave_t > 1.0) or _autosave_t > 15.0:
		save_run()


func _notification(what: int) -> void:
	if clock == null:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if onboarding != null:
				onboarding.interrupt("background")
			clock.suspend()
			save_run()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			clock.resume()
		NOTIFICATION_WM_CLOSE_REQUEST:
			save_run()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_go_back()


## Android back: one step out of wherever the player is (never straight out of the game in play).
func _go_back() -> void:
	if diagnostics != null and diagnostics.visible:
		diagnostics.close()
	elif presentation != null and presentation.active():
		presentation.back()
	elif pause_menu.visible:
		pause_menu.close()
	elif state == "play":
		pause_menu.open()
	elif state == "title":
		exit_game()


## Leaves the game from the title (Exit button, Android back): the run is saved first, then the app
## closes the way Android back on the title always has.
func exit_game() -> void:
	save_run()
	get_tree().quit()


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
	if frame_stats != null:
		L.append("  Frames " + frame_stats.line("title"))
		L.append("  Frames " + frame_stats.line("play"))
	if repop != null:
		L.append("  " + repop.summary())
	if hard != null:
		L.append("  " + hard.summary())
	if onboarding != null:
		L.append("  " + onboarding.status_text())
	if gill != null:
		L.append(gill.diagnostics_text())
		if starfish != null:
			L.append(starfish.diagnostics_text())
	L.append(AutoUpdate.diagnostics_text())
	return "\n".join(L)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state == "play":
		pause_menu.open()


func tank_flow() -> Vector3:
	return Vector3(1.2, 0.35, 0.4)


# --- Main loop ---------------------------------------------------------------------------

## World expansion, regional activation: parasites, motes and food further than this from him
## (on his own ball) pause, as creatures do beyond Critter.ACTIVE_RANGE.
const ACTIVE_RADIUS := 55.0
var _region_t := 0.0


## Whether the run stands still for the aquarium experiences (parasites, Motes, food pause).
static func paused_for_aquarium() -> bool:
	return inst != null and inst.state == "aquarium"


func near_player(pos: Vector3) -> bool:
	return pos.distance_squared_to(player.global_position) < ACTIVE_RADIUS * ACTIVE_RADIUS


## Title pacing (owner phone video, 2026-10-01): the orbit round him on the title showed uneven frames
## (17 ms and 50-67 ms mixed, 31-41 fps), which a continuous camera turn makes plain judder. When the
## title cannot hold 60, it runs at an even 30 instead; play and every other screen keep the
## project's rate. Measured from the frames themselves, so a phone that holds 60 is never capped.
const TITLE_PACE_SETTLE_S := 1.5
const TITLE_PACE_WINDOW := 90
var _pace_frames: Array[float] = []
var _pace_t := 0.0
var title_capped := false
var _fps0 := -1


func _title_pacing(dt: float) -> void:
	if _fps0 < 0:
		_fps0 = Engine.max_fps
	if state != "title" or (title != null and not title.visible) or Settings.test_mode != "":
		if title_capped:
			Engine.max_fps = _fps0
			title_capped = false
		_pace_frames.clear()
		_pace_t = 0.0
		return
	_pace_t += dt
	if title_capped or _pace_t < TITLE_PACE_SETTLE_S:
		return
	_pace_frames.append(dt)
	if _pace_frames.size() < TITLE_PACE_WINDOW:
		return
	if title_should_cap(_pace_frames):
		Engine.max_fps = 30
		title_capped = true
	_pace_frames.clear()


## Uneven or slow: more than 10 % of the frames over 25 ms (60 is not being held).
static func title_should_cap(frames: Array[float]) -> bool:
	var slow := 0
	for f in frames:
		if f > 0.025:
			slow += 1
	return slow > frames.size() / 10


func _process(dt: float) -> void:
	_title_pacing(dt)
	_region_t -= dt
	if _region_t <= 0.0 and cam != null:
		# Four times a second: each ball draws only what can be above the camera's horizon.
		_region_t = 0.25
		for b in balls:
			b.update_visibility(cam.global_position)
	_resume_position()
	clock.tick(dt, state == "play")
	if state == "play":
		_autosave(dt)
	if state == "aquarium":
		# The aquarium experiences: the run stands still (Presentation drives the camera).
		return
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
		_check_shrines()
		_check_vortex_entry()
		_update_tutorial(dt)
	_check_vortex_connections()
	_update_restoration(dt)
	_update_mote_lights()
	_update_food(dt)
	_update_repop(dt)
	_update_hard(dt)
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
			hud.show_all_clear("Finished in %s  ·  %d%% complete  ·  Skills %d/%d" % [RunClock.format(clock.finish_s), completion.percent_display(run_save.earned()),
					finish_skills(), SkillTree.COUNT] if clock.is_finished() else "")
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
	for par in p.ball.hostiles():
		if par.is_alive():
			out.append(par)
	for c in p.ball.critters:
		if c.active and c.hittable():
			out.append(c)
	for tgt in practice_targets:
		if is_instance_valid(tgt) and tgt.ball == p.ball and tgt.hittable():
			out.append(tgt)
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
	# A spitter's glob in reach is batted back (Expansion 6).
	for gl in ParasiteGlob.live.duplicate():
		if gl.ball == p.ball and not gl.reflected and gl.global_position.distance_to(p.body_center()) < SWIPE_REACH + 0.35:
			gl.deflect(p)
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
	# Treasure Hunt: only a lunge collects the current object (docs/TREASURE_HUNT.md).
	if treasure != null and treasure.try_collect(p, chest, tip):
		_hide_prompt("lunge", true)
		return true
	for f in p.ball.foods.duplicate():
		if not is_instance_valid(f) or not f.is_catchable():
			continue
		if _seg_dist(f.catch_point(), chest, tip) < LUNGE_CATCH_RADIUS + p.catch_bonus:
			_eat(p, f)
			return true
	for m in p.ball.motes:
		if m.is_available() and _seg_dist(m.global_position, chest, tip) < 0.9 + p.catch_bonus:
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
		# (Mote Magnet: a miss startles those it was drawing out of its pull for a moment.)
		if p.magnet_range > 0.0 and dist < p.magnet_range + 1.0:
			m.startle(p.magnet_startle)
	Sfx.play("lunge", p.global_position, -4.0)


func _eat(p: Axolotl, f: Food) -> void:
	var amount := f.heal_amount(p.max_health)
	var before := p.health
	p.heal(amount)
	stats["eaten"][f.type] += 1
	WaterFX.inst.sparkle(f.catch_point(), Color(1.0, 0.8, 0.6, 0.8), 8, 1.0, 0.05, 0.6)
	Sfx.play("eat_big" if f.type == Food.Type.BURROWER else "eat", p.global_position)
	p.model.happy_t = 0.0 if f.type == Food.Type.BURROWER else p.model.happy_t
	p.ball.foods.erase(f)
	if food != null:
		food.on_eaten(f)
	f.eaten()
	_hide_prompt("lunge", true)
	# (The healing above is the real one; the lesson only paces how the frond is SHOWN coming back.)
	onboarding.on_food_eaten(before)


func parasite_killed(par: Parasite) -> void:
	if par.returner:
		# Repopulation: a returner earns, restores and changes nothing (no id, no zone event).
		stats["returner_kills"] = int(stats.get("returner_kills", 0)) + 1
		WaterFX.inst.sparkle(par.global_position, Color(0.45, 1.0, 0.45, 0.9), 14, 1.6, 0.08, 1.0)
		Sfx.play("drain", par.global_position, -3.0)
		if repop != null:
			repop.on_killed(par, clock.play_s)
		if hard != null:
			hard.on_kill(par.ball.index, par.zone_id)
		_hide_prompt("swipe", true)
		return
	stats["kills"] += 1
	_earn(par.get_meta("completion_id", ""))
	var ball := par.ball
	if hard != null:
		hard.on_kill(ball.index, par.zone_id)
	# Stolen vitality returns to the moss.
	WaterFX.inst.sparkle(par.global_position, Color(0.45, 1.0, 0.45, 0.9), 22, 2.2, 0.08, 1.2)
	Sfx.play("drain", par.global_position)
	# Onboarding's first-parasite lesson stages how this restoration is SHOWN; the kill itself is
	# applied here exactly as always (the snapshot and the record only read).
	var staged := onboarding != null and onboarding.wants_kill_stage()
	var base: Image = ball.health_snapshot() if staged else null
	if staged:
		ball.record_heals_begin()
	ball.complete_event(par.zone_id, par.global_position, 12.0)
	_hide_prompt("swipe", true)
	if staged:
		onboarding.begin_kill(par, ball, base, ball.record_heals_end())
	elif onboarding != null:
		onboarding.kill_unstaged()


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
	if hard != null:
		hard.on_mote(m.ball.index, m.zone_id)
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
	for par in player.ball.hostiles():
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
		# (The parasite lesson's raised shot shows the same thing: it plays instead, once.)
		if onboarding != null and onboarding.claims_frame():
			return
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


## Tier-2 shrines (docs/TIER2.md): touching one in normal play gives Gill its ability for this run.
func _check_shrines() -> void:
	if player.state != "normal" or not player.controls_enabled or _resume_ball >= 0:
		return
	for s in player.ball.shrines:
		if s.taken or not s.is_placed():
			continue
		if s.touch_point().distance_to(player.body_center()) < 1.4:
			take_shrine(s)


## Gives the shrine's ability (first unlock is equipped), shows it, and sets out practice targets.
func take_shrine(s: Tier2Shrine) -> void:
	s.set_taken(true)
	if not tier2.unlock(s.ability):
		return
	WaterFX.inst.sparkle(s.touch_point(), Color(0.55, 0.95, 1.0, 0.95), 26, 2.0, 0.08, 1.4)
	Sfx.play("discover", null, -2.0)
	Settings.haptic("heavy")
	hud.show_discovery("%s!  %s" % [Tier2.NAMES[s.ability], Tier2.BLURBS[s.ability]])
	hud.reveal_special()
	_show_prompt("special")
	var k := 0
	for pos in s.practice:
		var tgt := PracticeTarget.new()
		tgt.place(s.ball, pos, 7700 + s.ball.index * 10 + k)
		practice_targets.append(tgt)
		k += 1
	save_run()


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


## Gill came down on a ravine's floor (world expansion): one frond, then a quick dissolve and he
## re-forms at the edge he fell from (Axolotl.ravine_return_point). On his last frond it is a
## death like any other: he re-forms at the last bloom, progress kept.
func ravine_fall(p: Axolotl) -> void:
	if cinematic != "" or p.state != "normal":
		return
	stats["ravine_falls"] = int(stats.get("ravine_falls", 0)) + 1
	if p.health <= 1:
		p.health = 0
		p.model.set_health(0, p.max_health, true)
		p.health_changed.emit(0, p.max_health)
		p.died.emit()
		return
	p.health -= 1
	p.model.set_health(p.health, p.max_health, true)
	p.health_changed.emit(p.health, p.max_health)
	Settings.haptic("hurt")
	Sfx.play("hurt", p.global_position)
	WaterFX.inst.impulse(p.global_position, 1.5, 0.5)
	_start_cinematic("ravine", {"to": p.ravine_return_point()})


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
	t2.cancel()
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
		"ravine":
			player.state = "cinematic"
			player.velocity = Vector3.ZERO
			Sfx.play("dissolve", player.global_position, -6.0)


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
		"ravine": _cine_ravine()
		"lesson": pass    # (Onboarding drives its own staged moments.)


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
	var look: Vector3 = v.visual_point(0.05 + 0.9 * smoothstep(0.0, 0.8, k))
	cam.cine_pos = a + v.dir_a * 7.0 + side * 9.0 + (look - a) * 0.25
	cam.cine_look = look
	cam.cine_up = v.dir_a.cross(side).normalized() * -1.0 if false else (Vector3.UP - v.dir_a * Vector3.UP.dot(v.dir_a)).normalized()
	if cine_t > 4.8:
		_end_cinematic()
		# Owner, 2026-10-01: the first tunnel of a run explains itself (a tutorial card).
		if onboarding != null:
			onboarding.on_tunnel_opened()


func _cine_travel(dt: float) -> void:
	var v: Vortex = cine_data["v"]
	var rev: bool = cine_data["reverse"]
	var dur := 6.0
	var k := clampf(cine_t / dur, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var t := 1.0 - e if rev else e
	# Corkscrew round the path beside a jet as the spiral revolves (Expansion 6), belly to the
	# jet, head toward the middle, banking into the turn.
	var s: Array = v.ride_pose(t)
	var pos: Vector3 = s[0]
	var fwd: Vector3 = s[1] * (-1.0 if rev else 1.0)
	var surf_up: Vector3 = s[2]
	var axis_p: Vector3 = s[3]
	var axis_f: Vector3 = s[4] * (-1.0 if rev else 1.0)
	var side := fwd.cross(surf_up).normalized()
	var bank := sin(k * TAU * 2.0) * 0.5
	player.global_position = pos
	player.global_basis = Basis(side, surf_up, -fwd).orthonormalized()
	player.model.surf = 1.0
	player.model.surf_bank = bank * 0.6
	player.model.grounded = false
	player.model.speed = 1.3
	if randf() < 0.6:
		WaterFX.inst._spawn_puff(pos + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 3.0, -fwd * 12.0, 0.4, 0.06, Color(0.8, 0.95, 1.0, 0.6), 0.5)
	# Camera: from the middle of the spiral, so he circles round it through the jets. Behind as it
	# grabs him, then alongside, then ahead to see his face, then behind again for the landing.
	var mid := axis_p.lerp(pos, 0.25)
	var cam_up := (surf_up * 0.35 + (v.sample(t)[2] as Vector3) * 0.65).normalized()
	var cp: Vector3
	var look := pos
	if k < 0.15:
		cp = pos - fwd * 3.0 + surf_up * 2.5 + side * 1.5
	elif k < 0.5:
		cp = mid - axis_f * 4.0
	elif k < 0.72:
		cp = mid - axis_f * 1.5 + surf_up * 0.8
	elif k < 0.9:
		cp = mid + axis_f * 3.2
	else:
		cp = pos - fwd * 3.5 + surf_up * 1.5
	cam.cine_pos = cam.cine_pos.lerp(cp, minf(1.0, dt * 4.0)) if cine_t > 0.05 else cp
	cam.cine_look = look
	cam.cine_up = cam_up
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


## A quick fade out of the ravine and back in at its edge (about 0.9 s; the camera follows).
## Owner, 2026-10-01: he lands in the ravine's ooze (RavineOoze), sinks slowly into it and is gone,
## then reforms on the rim as before.
const OOZE_SINK_S := 1.5
const OOZE_SINK_M := 0.9


func _cine_ravine() -> void:
	if cine_t < OOZE_SINK_S:
		if not cine_data.has("sinking"):
			cine_data["sinking"] = true
			Sfx.play("ooze_sink", player.global_position, -2.0)
		var k := cine_t / OOZE_SINK_S
		player.model.position.y = -OOZE_SINK_M * k * k * (3.0 - 2.0 * k)
		player.model.dissolve = smoothstep(0.65, 1.0, k)
		if int(cine_t * 30.0) % 4 == 0:
			WaterFX.inst.sparkle(player.global_position + player.up * RavineOoze.LEVEL, Color(0.5, 1.0, 0.25, 0.9), 2, 0.6, 0.08, 0.7)
	elif not cine_data.has("placed"):
		cine_data["placed"] = true
		var to: Array = cine_data["to"]
		player.model.position.y = 0.0
		player.place(to[0], to[1])
		Sfx.play("reform", to[1], -6.0)
		cam.snap_behind()
	else:
		var k := clampf((cine_t - OOZE_SINK_S) / 0.55, 0.0, 1.0)
		player.model.dissolve = 1.0 - k
		if k >= 1.0:
			player.state = "normal"
			player.invuln_t = 1.2
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
			# The bloom's pulse startles parasites off (Expansion 6): he never re-forms into an
			# attack he cannot answer.
			for par in b.hostiles():
				if par.is_alive() and par.global_position.distance_to(dest_pos) < Parasite.STARTLE_R:
					par.startle(dest_pos)
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

func _update_food(dt: float) -> void:
	food.update(dt, player.ball, player.global_position, cam)


## Twice a second in play: parasites may return to cleared zones on his ball (Repopulation).
func _update_repop(dt: float) -> void:
	_repop_t -= dt
	if _repop_t > 0.0 or repop == null or state != "play":
		return
	_repop_t = 0.5
	repop.update(clock.play_s, player.ball, player.global_position, cam)


## Four times a second of play: Hard Mode's tug of war (HardMode). Only in play (the clock's play
## seconds: nothing while closed, paused, on the title or in the aquarium).
func _update_hard(dt: float) -> void:
	if hard == null:
		return
	_hard_t -= dt
	if _hard_t > 0.0 or state != "play":
		return
	_hard_t = HardMode.TICK_S
	(repop.rules as HardMode.HardRules).slow = player.health <= 2
	hard.tick(clock.play_s, player.ball.index, player.health)
	var zk := hard.zone_at(player.ball.index, player.global_position - player.ball.global_position)
	hud.set_vitality(hard.ball_mean(player.ball.index), float(hard.v.get(zk, -1.0)), hard.losing.has(zk))


## Every ball restored and living (Hard Mode): a moment, not a completion entry.
func _on_living_aquarium() -> void:
	hud.show_discovery("Living aquarium")
	Sfx.play("discover", null, -4.0)


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
		var m1 := b.surface_point(Levels.tut_dir(Levels.TUT_M1_M))
		if player.global_position.distance_to(m1) < 4.8 and player.grounded:
			_show_prompt("jump")
	if not prompts_done.has("burst") and prompts_done.has("jump"):
		var m1 := balls[0].surface_point(Levels.tut_dir(Levels.TUT_M1_M), Levels.TUT_M1_TOP)
		if b.index == 0 and player.global_position.distance_to(m1) < 2.6:
			_show_prompt("burst")
	# (While the parasite and feeding lessons are still to come, they show the Tail Swipe and Lunge
	# prompts themselves, as their objectives: never twice.)
	if not prompts_done.has("swipe") and onboarding.done("parasite"):
		for par in b.hostiles():
			if par.is_alive() and par.global_position.distance_to(player.global_position) < 5.0:
				_show_prompt("swipe")
				break
	if not prompts_done.has("lunge"):
		for m in b.motes:
			if m.is_available() and m.global_position.distance_to(player.global_position) < 4.5:
				_show_prompt("lunge")
				break
		for f in b.foods:
			if not onboarding.done("feeding"):
				break
			if is_instance_valid(f) and f.is_catchable() and f.catch_point().distance_to(player.global_position) < 4.0:
				_show_prompt("lunge")
				break


func notify_action(action: String) -> void:
	match action:
		"jump": _hide_prompt("jump", true)
		"burst": _hide_prompt("burst", true)
		"camera": _hide_prompt("camera", true)
