extends RefCounted
## Onboarding checks (docs/ONBOARDING.md, ledger rows 20 and 24: once per run, Tutorials toggle). Called from unit_tests.gd, whose helpers
## (place_at, press, wait_grounded, _fit_problems ...) they use through `u`.

var u
var t
var g: Game
var p: Axolotl
var o: Onboarding


func _init(p_u) -> void:
	u = p_u
	t = u.t
	g = u.g
	p = u.p
	o = g.onboarding


# --- helpers -------------------------------------------------------------------------------------

## Clean slate: tutorials on, these of this run's lessons done (the rest not), no stage, no
## objective, no card, Gill well.
func reset(done_flags: Array) -> void:
	if o.stage != "":
		o.finish("test")
	o.ui.hide_card()
	o._set_objective("")
	Settings.tutorials = true
	var d := {}
	for f in done_flags:
		d[f] = true
	g.run_save.set_lessons(d)
	g.save_run()
	o.run_frond = false
	if g.cinematic != "":
		g._end_cinematic()
	g.state = "play"
	p.state = "normal"
	p.controls_enabled = true
	p.model.dissolve = 0.0
	p.restore_full()
	p.invuln_t = 0.0
	g.hud.visible_controls(true)
	await t.frames(2)


func all_done() -> void:
	await reset(Onboarding.FLAGS)


## This run's record as written on disk.
func on_disk() -> Dictionary:
	return RunSave.open(g.run_save.path).lessons()


## What a player's launch does with this process's run (Game._setup_onboarding, not the test switch).
func setup_as_player() -> void:
	var had: bool = Settings.test_args.has("onboarding")
	var was = Settings.test_args.get("onboarding")
	Settings.test_args["onboarding"] = "player"
	g._setup_onboarding()
	if had:
		Settings.test_args["onboarding"] = was
	else:
		Settings.test_args.erase("onboarding")


## Makes this process's run a new one (no clock, nothing earned, no record) and gives it its record
## as a launch does (New Run reloads the scene; Play with no saved run opens one like this).
func new_run() -> void:
	g.run_save.earned().clear()
	g.clock = RunClock.from_dict({"state": "not_started", "run_s": 0.0, "play_s": 0.0, "finish_s": -1.0})
	g.run_save.run().erase("onboarding")
	setup_as_player()


## A live, visible jellyfish (a drifter) `ahead` m in front of Gill, hovering at his head's height.
func jelly(ahead := 3.5, side := 0.0) -> Food:
	var b := p.ball
	var right := p.facing.cross(p.up).normalized()
	var at := p.global_position + p.facing * ahead + right * side
	var d := b.up_at(at)
	var f := Food.new()
	f.setup(b, Food.Type.DRIFTER, b.surface_point(d, 0.7), d, 25.0)
	f.state = "idle"
	b.add_child(f)
	b.foods.append(f)
	# (In front: somewhere the camera really sees it, not behind a stem or a mound.)
	if ahead > 0.0 and not o.visible_to_player(f.global_position, Onboarding.FOOD_SEE_M):
		for cand in [[ahead, -1.5], [ahead, 1.5], [ahead - 1.5, 0.0], [ahead + 1.5, 0.0], [ahead - 1.5, -2.0], [ahead - 1.5, 2.0], [ahead + 2.5, -1.0], [ahead + 2.5, 1.0]]:
			var at2: Vector3 = p.global_position + p.facing * float(cand[0]) + right * float(cand[1])
			f.global_position = b.surface_point(b.up_at(at2), 0.7)
			if o.visible_to_player(f.global_position, Onboarding.FOOD_SEE_M):
				break
	return f


## Somewhere open on ball `bi` (its start), Gill facing along it, camera behind.
func home(bi := 0) -> void:
	var b := g.balls[bi]
	var d := b.start_dir
	u.place_at(bi, b.surface_point(d, 0.1), -MossBall.frame_at(d, 180.0).z)
	await t.frames(2)
	g.cam.snap_behind()
	await u.wait_grounded()
	g.cam.snap_behind()


## The nearest live parasite to a ball's start (or null).
func a_parasite(bi: int) -> Parasite:
	var b := g.balls[bi]
	var best: Parasite = null
	for par in b.parasites:
		if par.is_alive() and (best == null or par.global_position.distance_to(b.surface_point(b.start_dir)) < best.global_position.distance_to(b.surface_point(b.start_dir))):
			best = par
	return best


## Gill `dist` m from `par`, facing it, camera behind him: on ordinary ground, never on or in a
## ravine (a ravine floor would cost him a frond and put him back at its rim, a ravine cinematic,
## once a lesson gives his controls back: which parasite is nearest depends on what earlier tests
## cleared, and one lies beside Ball 1's great ravine).
func face(par: Parasite, dist := 6.0) -> void:
	var b := par.ball
	var pp := par.global_position
	var up := b.up_at(pp)
	var side := MossBall.frame_at(up, 0.0).z
	var d := b.up_at(pp + side * dist)
	for k in 16:
		var cand := b.up_at(pp + side.rotated(up, TAU * k / 16.0) * dist)
		if b.ravine_carve(cand) < 0.02 and b.ravine_at(cand) == "":
			d = cand
			break
	var from := b.surface_point(d, 0.1)
	u.place_at(b.index, from, pp - from)
	p.invuln_t = 999.0
	await t.frames(3)
	g.cam.snap_behind()
	await t.frames(2)


func wait_until(cond: Callable, secs: float) -> bool:
	for i in int(secs * 60.0):
		if cond.call():
			return true
		await t.frames(1)
	return cond.call()


func kill(par: Parasite) -> void:
	par.hit_cd = 0.0
	par.hit(par.hp, par.global_position)


static func img_md5(img: Image) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_MD5)
	hc.update(img.get_data())
	return hc.finish().hex_encode()


# --- The per-run record and the legacy profile record ----------------------------------------------

func progress() -> void:
	var path := ProjectSettings.globalize_path("user://onb_record_test.json")
	RunSave.erase(path)
	var rs := RunSave.open(path)
	t.check("onb_new_run_save_has_no_record", not rs.has_lessons() and rs.lessons().is_empty(), str(rs.run().keys()))
	rs.set_lessons({"intro": true, "frond": true})
	rs.save()
	var re := RunSave.open(path)
	t.check("onb_record_persists_in_run_save", re.has_lessons() and re.lessons().has("intro") and bool(re.lessons().get("frond", false))
			and not re.lessons().has("feeding"), str(re.lessons()))
	re.start_new_run()
	t.check("onb_new_run_drops_record", not re.has_lessons(), str(re.run().keys()))
	# A run saved before the record existed: opening (and migrating) it never adds one.
	var old := RunSave.new_data({})
	(old["run"] as Dictionary).erase("onboarding")
	old["run"]["clock"] = {"state": "running", "run_s": 50.0, "play_s": 50.0, "finish_s": -1.0}
	RunSave.erase(path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	t.check("onb_old_run_save_stays_without_record", not RunSave.open(path).has_lessons(), "")
	RunSave.erase(path)
	# The once-per-profile builds' keys: loaded harmlessly, kept as they were, never read.
	var gpath := ProjectSettings.globalize_path("user://onb_legacy_profile.json")
	GillProgress.erase(gpath)
	var doc := {"format": GillProgress.FORMAT, "kind": GillProgress.KIND, "seq": 3, "collected": {StarfishTable.ids()[0]: {"t": 1, "v": "1.0.0"}},
			"purchased": {}, "onboarding": {"intro": true, "feeding": true, "first_frond": true}, "onboarding_epoch": 2}
	var f2 := FileAccess.open(gpath, FileAccess.WRITE)
	f2.store_string(JSON.stringify(doc))
	f2.close()
	var gp := GillProgress.open(gpath)
	var loaded_ok := gp.origin.begins_with("loaded") and gp.stars() == 1 and not gp.read_only
	gp.save()
	var back: Dictionary = GillProgress._read(gpath)["data"]
	t.check("onb_legacy_profile_keys_load_harmlessly", loaded_ok and GillProgress.open(gpath).stars() == 1
			and JSON.stringify(back.get("onboarding")) == JSON.stringify(doc["onboarding"]) and int(back.get("onboarding_epoch", 0)) == 2,
			"origin '%s'; written back %s epoch %s" % [gp.origin, back.get("onboarding"), back.get("onboarding_epoch")])
	GillProgress.erase(gpath)
	# A profile without them never gains them.
	var gp2 := GillProgress.open(gpath)
	gp2.save()
	t.check("onb_profile_never_gains_onboarding_keys", not (GillProgress._read(gpath)["data"] as Dictionary).has("onboarding"), "")
	GillProgress.erase(gpath)


## The owner's phone save (2026-10-01): a run in progress at about 46% (184 of the catalog's entries,
## 1:12:40 on the clock, not finished), Red Starfish 3/30, Skills 3/15, 0 to spend, format 1 merged
## with its backup, from before the per-run record. After the update: Continue shows no intro and no
## lesson, the frond is not emptied, the run counts all its lessons as done, and nothing else in the
## run or the profile changes.
func owner_save() -> void:
	var run_path := ProjectSettings.globalize_path("user://onb_owner_run.json")
	var gill_path := ProjectSettings.globalize_path("user://onb_owner_gill.json")
	RunSave.erase(run_path)
	GillProgress.erase(gill_path)
	# The run.
	var rs := RunSave.open(run_path)
	var e := rs.earned()
	# (The vortices this much restoration has opened are earned with it, as in a real save.)
	var vortices := ["vortex.b1-b2", "vortex.b2-b3", "vortex.b1-b4", "vortex.b2-b5", "vortex.b3-b6"]
	var n := 0
	for id in g.completion.order:
		if n >= 184 - vortices.size():
			break
		if id == Completion.ENDING_ID or id.ends_with(".restored") or id.begins_with("vortex."):
			continue
		e[id] = 10.0 + n * 23.0
		n += 1
	for v in vortices:
		e[v] = 10.0 + n * 23.0
		n += 1
	rs.run()["clock"] = {"state": "running", "run_s": 4360.0, "play_s": 4360.0, "finish_s": -1.0}
	rs.run()["world"] = {"ball": 2, "checkpoint": "", "prompts_done": ["move", "jump", "burst", "swipe", "lunge", "camera"], "tut_framed": true,
			"all_clear_shown": false, "stats": {}}
	rs.save()
	# The profile: three starfish, three one-starfish skills; written twice so there is a backup.
	var gp := GillProgress.open(gill_path)
	var ids := StarfishTable.ids()
	for i in 3:
		gp.collected[ids[i]] = {"t": 1759300000 + i, "v": "1.0.0"}
	gp.save()
	var bought := 0
	for pass_ in 4:
		for sid in SkillTree.ids():
			if bought < 3 and not gp.owns(sid) and SkillTree.cost(sid) == 1 and SkillTree.missing(sid, gp.purchased).is_empty():
				gp.purchased[sid] = {"cost": 1, "t": 1759300100 + bought, "n": bought + 1}
				bought += 1
	gp.save()
	var pct := g.completion.percent(e)
	var before_run := RunSave._read(run_path)["data"] as Dictionary
	var before_gill := GillProgress._read(gill_path)["data"] as Dictionary
	t.check("onb_owner_fixture", e.size() == 184 and gp.stars() == 3 and gp.skills() == 3 and gp.balance() == 0 and FileAccess.file_exists(gill_path + ".bak")
			and not before_gill.has("onboarding") and not (before_run["run"] as Dictionary).has("onboarding"),
			"%d earned (%.2f%% of %d), stars %d, skills %d, balance %d" % [e.size(), pct, g.completion.size(), gp.stars(), gp.skills(), gp.balance()])
	# The updated game opens it (a fresh process, as on the phone; tutorials on, the default).
	var res := _child("_phase_onb_owner", ["--run-save=" + run_path, "--gill-save=" + gill_path, "--onboarding=player"])
	t.check("onb_owner_child_ran", res == 0, "exit %d" % res)
	var after_gill := GillProgress._read(gill_path)["data"] as Dictionary
	var after_run := RunSave._read(run_path)["data"] as Dictionary
	var ar: Dictionary = (after_run["run"] as Dictionary)
	var rec: Dictionary = ar.get("onboarding", {})
	var all4 := true
	for f in Onboarding.FLAGS:
		all4 = all4 and bool(rec.get(f, false))
	t.check("onb_owner_run_counts_lessons_done", all4 and not rec.has("frond"), str(rec))
	t.check("onb_owner_profile_unchanged", JSON.stringify(after_gill["collected"]) == JSON.stringify(before_gill["collected"])
			and JSON.stringify(after_gill["purchased"]) == JSON.stringify(before_gill["purchased"]) and not after_gill.has("onboarding")
			and GillProgress.open(gill_path).balance() == 0,
			"collected %d, purchased %d, keys %s" % [(after_gill["collected"] as Dictionary).size(), (after_gill["purchased"] as Dictionary).size(), after_gill.keys()])
	var br: Dictionary = (before_run["run"] as Dictionary)
	var clock_ok := float(ar["clock"]["run_s"]) >= 4360.0 and float(ar["clock"]["run_s"]) < 4360.0 + 30.0 and str(ar["clock"]["state"]) == "running"
	t.check("onb_owner_run_unchanged", JSON.stringify(ar["earned"]) == JSON.stringify(br["earned"]) and ar["id"] == br["id"]
			and JSON.stringify(after_run["records"]) == JSON.stringify(before_run["records"]) and clock_ok,
			"earned %d -> %d, run time %.1f -> %.1f (the continued play only)" % [(br["earned"] as Dictionary).size(), (ar["earned"] as Dictionary).size(),
			float(br["clock"]["run_s"]), float(ar["clock"]["run_s"])])
	RunSave.erase(run_path)
	GillProgress.erase(gill_path)


## In the child: the owner's save as the updated game opens it, then Continue.
func phase_owner() -> void:
	var rs := g.run_save
	var all4 := rs.has_lessons()
	for f in Onboarding.FLAGS:
		all4 = all4 and rs.lessons().has(f) and o.done(f)
	t.check("owner_run_counts_all_lessons_done", all4 and Settings.tutorials and not o.run_frond, str(rs.lessons()))
	var gp := g.gill
	t.check("owner_profile_intact", gp.stars() == 3 and gp.skills() == 3 and gp.balance() == 0 and not gp.onb_known, "%d %d %d" % [gp.stars(), gp.skills(), gp.balance()])
	var on_disk_run := RunSave._read(g.run_save.path)["data"]["run"]["earned"] as Dictionary
	var extra: Array = g.run_save.earned().keys().filter(func(k) -> bool: return not on_disk_run.has(k))
	t.check("owner_run_in_progress", g.has_run_in_progress() and on_disk_run.size() == 184, "%d earned on disk; in memory also %s" % [on_disk_run.size(), extra])
	# Continue from the title, as on the phone.
	g._enter_title()
	await t.frames(10)
	t.check("owner_title_offers_continue", g.title._play.text == "Continue", g.title._play.text)
	g.title._on_play()
	await t.frames(5)
	t.check("owner_continue_no_intro", o.ui.card_kind() == "" and g.state == "play" and p.controls_enabled, "card '%s', state %s" % [o.ui.card_kind(), g.state])
	t.check("owner_frond_not_emptied", p.health == p.max_health, "%d/%d" % [p.health, p.max_health])
	# Play on for a while, with food and parasites about: no lesson, no objective, no card.
	var f := jelly(3.0)
	var seen := false
	for i in 240:
		await t.frames(1)
		seen = seen or o.objective != "" or o.stage != "" or o.ui.card_kind() != ""
	p.health = p.max_health - 1
	g._eat(p, f)
	await t.frames(30)
	seen = seen or o.stage != "" or g.cinematic == "lesson" or o.ui.card_kind() != ""
	t.check("owner_no_lesson_on_continue", not seen, "objective '%s' stage '%s'" % [o.objective, o.stage])
	g.save_run()


# --- Once per run ---------------------------------------------------------------------------------

## Every new run (tutorials on) has the intro, the three lessons and the empty frond again; Continue
## keeps what this run has done; a run with no record counts them all as done.
func per_run() -> void:
	await reset([])
	await home(0)
	p.invuln_t = 999.0
	var saved_clock := g.clock.to_dict()
	var saved_earned: Dictionary = g.run_save.earned().duplicate()
	var mx := p.max_health
	var why: Array[String] = []
	for run_i in 3:
		new_run()
		var fresh := o.intro_due(false) and not o.done("intro") and not o.done("feeding") and not o.done("parasite") and not o.done("starfish")
		p.restore_full()
		o.on_play_started(false)
		var frond := p.health == mx - 1 and p.model.health == mx - 1 and o.run_frond and bool(g.run_save.lessons().get("frond", false))
		if not fresh or not frond:
			why.append("run %d: lessons fresh %s, frond %s (%d/%d)" % [run_i + 1, fresh, frond, p.health, mx])
		# Played through: each lesson done in this run.
		for fl in Onboarding.FLAGS:
			o._mark(fl)
		g.run_save.lessons().erase("frond")
		o.run_frond = false
		if not o.all_done() or o.intro_due(false):
			why.append("run %d: not done after marking" % (run_i + 1))
	t.check("onb_lessons_replay_each_new_run", why.is_empty(), "; ".join(why))
	# Continue keeps this run's lessons (as written at once) and its pending empty frond.
	new_run()
	g.clock = RunClock.from_dict({"state": "running", "run_s": 30.0, "play_s": 30.0, "finish_s": -1.0})
	p.restore_full()
	o.on_play_started(false)
	o._mark("intro")
	o._mark("parasite")
	var disk := on_disk()
	g.run_save.set_lessons(disk.duplicate())
	p.restore_full()
	setup_as_player()
	o.on_play_started(true)
	t.check("onb_continue_keeps_run_lessons", disk.has("intro") and disk.has("parasite") and not disk.has("feeding") and o.done("parasite")
			and not o.done("feeding") and not o.done("starfish") and not o.intro_due(true) and p.health == mx - 1 and o.run_frond,
			"on disk %s; hp %d/%d" % [disk, p.health, mx])
	# A run with no record (one saved before it existed) counts every lesson as done: no frond.
	g.run_save.run().erase("onboarding")
	p.restore_full()
	setup_as_player()
	o.on_play_started(true)
	var f := jelly(4.0)
	p.health = mx - 1
	await t.seconds(1.0)
	t.check("onb_run_without_record_counts_done", o.all_done() and g.run_save.has_lessons() and not o.run_frond and o.objective == ""
			and o.stage == "", "record %s, objective '%s'" % [g.run_save.lessons(), o.objective])
	g._eat(p, f)
	await t.frames(5)
	t.check("onb_run_without_record_no_lesson", o.stage == "" and g.cinematic == "" and o.ui.card_kind() == "", "stage '%s'" % o.stage)
	# Tutorials off: a new run has no intro, no lesson and no empty frond (full health).
	Settings.tutorials = false
	new_run()
	p.restore_full()
	o.on_play_started(false)
	t.check("onb_off_new_run_nothing", not o.intro_due(false) and o.all_done() and p.health == mx and not o.run_frond
			and g.run_save.has_lessons() and g.run_save.lessons().is_empty(), "hp %d/%d, record %s" % [p.health, mx, g.run_save.lessons()])
	# Through the title as a player: Play goes straight into play.
	g._enter_title()
	await t.frames(10)
	g.title._on_play()
	await t.frames(5)
	t.check("onb_off_play_straight_in", o.ui.card_kind() == "" and g.state == "play" and p.controls_enabled and p.health == mx,
			"card '%s', state %s, hp %d/%d" % [o.ui.card_kind(), g.state, p.health, mx])
	await home(0)
	p.invuln_t = 999.0
	p.health = mx - 1
	var f2 := jelly(5.0)
	await t.seconds(1.0)
	t.check("onb_off_no_objective", o.objective == "" and o.ui.card_kind() == "", "objective '%s'" % o.objective)
	# Back on mid-run: no intro; this run's lessons not yet done may still come.
	Settings.tutorials = true
	o.tutorials_changed(true)
	var on := await wait_until(func() -> bool: return o.objective == "feeding", 2.0)
	t.check("onb_on_again_mid_run_lessons_may_come", on and o.ui.card_kind() == "" and g.state == "play", "objective '%s'" % o.objective)
	if is_instance_valid(f2):
		p.ball.foods.erase(f2)
		f2.queue_free()
	# Restore this process's run.
	g.run_save.earned().clear()
	for k in saved_earned:
		g.run_save.earned()[k] = saved_earned[k]
	g.clock = RunClock.from_dict(saved_clock)
	await all_done()


# --- The Tutorials toggle ----------------------------------------------------------------------------

## Settings' Tutorials toggle: on by default (also for a settings file from before it), shown in-run
## and from the title, persisted across a restart, and turning it off mid-lesson ends it cleanly.
func toggle() -> void:
	var pm := g.pause_menu
	# An older settings file (no [onboarding] section) reads as on.
	var keep := FileAccess.get_file_as_string(Settings.SETTINGS_PATH) if FileAccess.file_exists(Settings.SETTINGS_PATH) else ""
	var cf := ConfigFile.new()
	cf.load(Settings.SETTINGS_PATH)
	if cf.has_section("onboarding"):
		cf.erase_section("onboarding")
	cf.set_value("hud", "haptics", false)
	cf.save(Settings.SETTINGS_PATH)
	var fresh: Node = load("res://scripts/core/settings.gd").new()
	fresh._load()
	t.check("tutorials_default_on_for_older_settings", fresh.tutorials == true and fresh.haptics == false, "")
	fresh.free()
	if keep != "":
		var w := FileAccess.open(Settings.SETTINGS_PATH, FileAccess.WRITE)
		w.store_string(keep)
		w.close()
	await reset([])
	# In-run Settings: the toggle is there and on; turning it off saves it.
	pm.open()
	await t.frames(3)
	var tb := pm._panel.find_child("Tutorials", true, false) as CheckButton
	t.check("tutorials_toggle_in_run_settings", tb != null and tb.is_visible_in_tree() and tb.button_pressed and tb.get_global_rect().size.y >= 56.0, "")
	if tb == null:
		pm.close()
		return
	tb.button_pressed = false
	var cf2 := ConfigFile.new()
	cf2.load(Settings.SETTINGS_PATH)
	t.check("tutorials_off_saved", not Settings.tutorials and cf2.get_value("onboarding", "tutorials", true) == false, "")
	pm.close()
	await t.frames(2)
	# A restart (a fresh process, a new run): still off, so no intro, no lesson, full health.
	var run_path := ProjectSettings.globalize_path("user://onb_toggle_run.json")
	RunSave.erase(run_path)
	var code := _child("_phase_onb_toggle", ["--run-save=" + run_path, "--onboarding=player"])
	t.check("tutorials_off_persists_across_restart", code == 0, "exit %d" % code)
	RunSave.erase(run_path)
	# From the title's Settings: there too; back on.
	g._enter_title()
	await t.frames(5)
	pm.open(true)
	await t.frames(3)
	t.check("tutorials_toggle_in_title_settings", tb.is_visible_in_tree() and not tb.button_pressed, "")
	tb.button_pressed = true
	var cf3 := ConfigFile.new()
	cf3.load(Settings.SETTINGS_PATH)
	t.check("tutorials_on_saved", Settings.tutorials and cf3.get_value("onboarding", "tutorials", false) == true, "")
	pm.close()
	await t.frames(2)
	g.title.hide_title()
	g.start_play(true)
	await t.frames(3)
	# Off mid-lesson: the feeding objective ends at once (the target let go, the prompt gone).
	await reset(["intro", "parasite", "starfish"])
	await home(0)
	p.invuln_t = 999.0
	p.health = p.max_health - 1
	var f := jelly(5.0)
	var on := await wait_until(func() -> bool: return o.objective == "feeding", 2.0)
	pm.open()
	await t.frames(2)
	tb.button_pressed = false
	pm.close()
	await t.frames(3)
	t.check("tutorials_off_ends_objective", on and o.objective == "" and o.food_target == null and f.anchor == Vector3.INF
			and not g.hud.prompts.has("lunge") and p.controls_enabled and g.cinematic == "", "armed %s, objective '%s'" % [on, o.objective])
	g._eat(p, f)
	await t.frames(3)
	t.check("tutorials_off_eating_no_lesson", o.stage == "" and g.cinematic == "" and o.ui.card_kind() == "", "stage '%s'" % o.stage)
	# Off during the staged restoration: it ends cleanly, the moss as it truly is, control back.
	await _start_kill_stage()
	if o.stage == "kill":
		var b: MossBall = o._kill["ball"]
		await t.seconds(1.0)
		Settings.tutorials = false
		o.tutorials_changed(false)
		await t.frames(3)
		t.check("tutorials_off_ends_staged_lesson", o.stage == "" and not b.staging() and g.cinematic == "" and p.controls_enabled
				and o.last_end == "off" and o.ui.card_kind() == "", "last end '%s'" % o.last_end)
	else:
		t.check("tutorials_off_ends_staged_lesson", false, "no kill stage to end (stage '%s')" % o.stage)
	# Off with a card up.
	await _start_star_card()
	Settings.tutorials = false
	o.tutorials_changed(false)
	await t.frames(2)
	t.check("tutorials_off_ends_card", o.stage == "" and o.ui.card_kind() == "" and p.controls_enabled and g.cinematic == "", o.last_end)
	Settings.tutorials = true
	Settings.save()
	await all_done()


## In the child: launched with Tutorials off saved; a new run.
func phase_toggle() -> void:
	t.check("toggle_child_reads_off", not Settings.tutorials, "")
	t.check("toggle_child_new_run_nothing", not g.has_run_in_progress() or g.clock.play_s < 5.0, "")
	t.check("toggle_child_no_intro_no_lessons", not o.intro_due(false) and o.all_done() and p.health == p.max_health and not o.run_frond,
			"hp %d/%d" % [p.health, p.max_health])
	g.pause_menu.open()
	await t.frames(3)
	var tb := g.pause_menu._panel.find_child("Tutorials", true, false) as CheckButton
	t.check("toggle_child_shows_off", tb != null and not tb.button_pressed, "")
	g.pause_menu.close()


func _child(phase: String, extra: Array) -> int:
	var base: Array = ["--headless", "--fixed-fps", "60", "--max-fps", "0", "--path", ProjectSettings.globalize_path("res://")]
	# (Run from a published pack, the child must load the same pack: there is no project folder. The
	# engine consumes --main-pack, so the pack tests also pass it as --pack=<path>.)
	var pack: String = Settings.test_args.get("pack", "")
	var args := OS.get_cmdline_args()
	var mp := args.find("--main-pack")
	if pack == "" and mp >= 0 and mp + 1 < args.size():
		pack = args[mp + 1]
	if pack != "":
		base = ["--headless", "--fixed-fps", "60", "--max-fps", "0", "--main-pack", pack]
	var out := []
	var cmd: Array = base + ["--", "--test=unit", "--only=" + phase, "--out=" + ProjectSettings.globalize_path("user://onb_child_out")] + extra
	var code := OS.execute(OS.get_executable_path(), cmd, out, true)
	for line in str(out[0]).split("\n"):
		if line.begins_with("[TEST] PASS") or line.begins_with("[TEST] FAIL"):
			var parts := line.substr(7).split(" ", false, 2)
			t.check("child/" + parts[1], parts[0] == "PASS", parts[2] if parts.size() > 2 else "")
	if code != 0:
		t.log_line("%s exited %d; output:\n%s" % [phase, code, str(out[0]).right(3000)])
	return code


# --- The intro ---------------------------------------------------------------------------------------

func intro() -> void:
	await reset([])
	# Make this process's run look new (no clock, nothing earned), as Play with no saved run sees it.
	var saved_clock := g.clock.to_dict()
	var saved_earned: Dictionary = g.run_save.earned().duplicate()
	g.run_save.earned().clear()
	g.clock = RunClock.from_dict({"state": "not_started", "run_s": 0.0, "play_s": 0.0, "finish_s": -1.0})
	g._enter_title()
	await t.frames(10)
	t.check("intro_title_offers_play", g.title._play.text == "Play", g.title._play.text)
	g.title._on_play()
	await t.frames(5)
	var card := o.ui.panel()
	var texts: Array[String] = []
	for l in card.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	t.check("intro_shows_on_first_new_run", o.ui.card_kind() == "intro" and texts.has(Onboarding.INTRO_TITLE) and texts.has(Onboarding.INTRO_BODY[0])
			and texts.has(Onboarding.INTRO_BODY[1]) and o.ui.button().text == "Begin", ", ".join(texts))
	t.check("intro_holds_play_and_clock", g.state == "title" and not p.controls_enabled and g.clock.state == "not_started" and not g.title.visible,
			"state %s, controls %s, clock %s" % [g.state, p.controls_enabled, g.clock.state])
	await layout_checks("intro")
	# Closing the app on the intro (no Begin): still to be seen.
	t.check("intro_not_seen_until_begin", not on_disk().has("intro"), str(on_disk()))
	# One large button: Begin starts play.
	var br := o.ui.button().get_global_rect()
	t.check("intro_one_large_button", br.size.y >= 80.0 and br.size.x >= 240.0, str(br.size))
	await t.frames(30)
	o.ui.tap()
	await t.frames(5)
	t.check("intro_begin_starts_play", g.state == "play" and p.controls_enabled and g.clock.state == "running" and o.ui.card_kind() == "",
			"state %s, clock %s" % [g.state, g.clock.state])
	t.check("intro_seen_persisted_in_run", on_disk().has("intro") and not o.intro_due(false), str(on_disk()))
	# Once per run (owner ruling, 2026-10-01): the next new run shows it again.
	new_run()
	t.check("intro_due_again_next_new_run", o.intro_due(false) and not o.done("feeding") and not o.done("parasite"), "")
	g._enter_title()
	await t.frames(5)
	g.title._on_play()
	await t.frames(5)
	t.check("intro_shows_on_later_new_run", o.ui.card_kind() == "intro" and g.state == "title", "card '%s'" % o.ui.card_kind())
	o.ui.tap()
	await t.frames(5)
	t.check("intro_later_begin_starts_play", o.ui.card_kind() == "" and g.state == "play" and p.controls_enabled, "state %s" % g.state)
	# Continue never shows it, even in a run that has not seen it.
	await reset([])
	t.check("intro_never_on_continue", not o.intro_due(true) and o.intro_due(false), "")
	# Restore this process's run.
	for k in saved_earned:
		g.run_save.earned()[k] = saved_earned[k]
	g.clock = RunClock.from_dict(saved_clock)
	await all_done()


## The card's layout at three landscape shapes (with a phone's cut-out on the left).
func layout_checks(tag: String) -> void:
	var bad: Array[String] = []
	var vp := g.get_viewport().get_visible_rect().size
	for sz in [Vector2(1280, 720), Vector2(1600, 720), Vector2(2000, 900)]:
		# (The design is scaled to the real window; an area of the same shape inside it.)
		var k := minf(vp.x / sz.x, vp.y / sz.y)
		var area := Rect2(Vector2(90, 16) * k, (sz - Vector2(90 + 24, 32)) * k)
		o.ui.layout_in(area, clampf(sz.y / 720.0, 0.75, 1.5) * k)
		await t.frames(2)
		o.ui.layout_in(area, clampf(sz.y / 720.0, 0.75, 1.5) * k)
		await t.frames(1)
		var why: String = u._fit_problems(o.ui.panel(), area, 72.0 * k)
		if why != "" or not area.encloses(o.ui.panel().get_global_rect()):
			bad.append("%s: %s (panel %s, area %s)" % [sz, why, o.ui.panel().get_global_rect(), area])
	o.ui._layout()
	await t.frames(2)
	t.check("onb_card_fits_%s" % tag, bad.is_empty(), "; ".join(bad))


# --- Lesson 1: feeding ---------------------------------------------------------------------------

func feeding() -> void:
	await reset(["intro", "parasite", "starfish"])
	await home(0)
	p.invuln_t = 999.0
	# A new run: one unlocked frond starts empty (never a locked one).
	o.on_play_started(false)
	var mx := p.max_health
	t.check("feed_new_run_one_frond_empty", p.health == mx - 1 and p.model.health == mx - 1 and o.run_frond and bool(g.run_save.lessons().get("frond", false)),
			"%d/%d" % [p.health, mx])
	# Continue keeps it empty while the lesson is still to come.
	p.restore_full()
	o.on_play_started(true)
	t.check("feed_continue_keeps_frond_empty", p.health == mx - 1 and o.run_frond, "%d/%d" % [p.health, mx])
	# Not visible (behind him): no objective.
	var behind := jelly(-4.0)
	await t.frames(30)
	t.check("feed_waits_until_visible", o.objective == "" and o.food_target == null, "objective '%s'" % o.objective)
	behind.queue_free()
	p.ball.foods.erase(behind)
	var f := jelly(5.0)
	var on := await wait_until(func() -> bool: return o.objective == "feeding", 2.0)
	if not on:
		var cam := g.cam
		var sp := cam.unproject_position(f.global_position)
		t.log_line("feed dbg: ok %s state %s catch %s ball %s dist %.2f frustum %s screen %s vis %s alt %.2f playing %s hp %d/%d" % [o._food_ok(f), f.state, f.is_catchable(), f.ball == p.ball,
				f.global_position.distance_to(p.global_position), cam.is_position_in_frustum(f.global_position), sp, o.visible_to_player(f.global_position, 11.0),
				f.ball.altitude(f.global_position), o._playing(), p.health, p.max_health])
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, f.global_position, 1 | 2)
		q.exclude = [p.get_rid()]
		var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
		t.log_line("feed dbg2: vp %s hit %s" % [cam.get_viewport().get_visible_rect().size, str(hit.get("collider")) + " " + str(hit.get("position", Vector3.ZERO).distance_to(f.global_position)) if not hit.is_empty() else "none"])
	t.check("feed_objective_when_visible", on and o.food_target == f and o.ui.objective_text() == Onboarding.OBJ_FEED and g.hud.prompts.has("lunge")
			and f.anchor != Vector3.INF, "objective '%s', text '%s'" % [o.objective, o.ui.objective_text()])
	t.check("feed_gill_never_frozen", p.controls_enabled and g.cinematic == "" and not o.ui.waiting_for_tap(), "")
	# Repeated misses: lunging the wrong way three times; he can still move and the target stays.
	for i in 3:
		p.facing = -p.facing
		await u.press("lunge")
		await t.seconds(0.6)
	t.check("feed_repeated_misses", o.objective == "feeding" and is_instance_valid(f) and o.food_target == f and p.controls_enabled, "")
	# The target cannot be lost: pushed far off, it comes back toward where it was seen.
	var anchor := f.anchor
	f.global_position += MossBall.frame_at(p.up, 0.0).x * 7.0
	f.vel = Vector3.ZERO
	await t.seconds(5.0)
	t.check("feed_target_recovers", is_instance_valid(f) and f.global_position.distance_to(anchor) < 3.0 and o.food_target == f,
			"%.2f m from where it was seen" % f.global_position.distance_to(anchor))
	# Damage during the objective: it stays.
	p.invuln_t = 0.0
	p.take_damage(1, p.global_position + p.facing)
	await t.seconds(0.5)
	t.check("feed_survives_damage", o.objective == "feeding", "hp %d" % p.health)
	p.health = mx - 1
	p.model.set_health(p.health, mx, false)
	# A Mote catch is not food: no bypass.
	t.check("feed_no_bypass_without_eating", not o.done("feeding"), "")
	# Eat it (what a lunge's contact does): the healing is the real one, at once.
	u.place_at(p.ball.index, p.ball.surface_point(p.ball.up_at(f.global_position - p.facing * 0.8), 0.1), p.facing)
	var before := p.health
	g._eat(p, f)
	t.check("feed_heal_applied_normally", p.health == before + 1 and o.done("feeding") and on_disk().has("feeding") and not on_disk().has("frond"),
			"%d -> %d" % [before, p.health])
	t.check("feed_frond_restore_deferred", p.model.health == before and g.cinematic == "lesson" and not p.controls_enabled and o.stage == "feed",
			"model %d, cinematic '%s'" % [p.model.health, g.cinematic])
	await t.seconds(Onboarding.CLOSE_S + 0.3)
	var head := p.head_position()
	t.check("feed_camera_close_on_fronds", g.cam.global_position.distance_to(head) < 3.0 and g.cam.is_position_in_frustum(head),
			"camera %.2f m from his head" % g.cam.global_position.distance_to(head))
	t.check("feed_frond_restores_visibly", p.model.health == p.health and p.model.frond_restore_progress() < 1.0, "progress %.2f" % p.model.frond_restore_progress())
	var carded := await wait_until(func() -> bool: return o.ui.waiting_for_tap(), 6.0)
	var texts: Array[String] = []
	for l in o.ui.panel().find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	t.check("feed_card_after_restore", carded and texts.has(Onboarding.FEED_TITLE) and o.ui.button().text == "Got it" and p.model.frond_restore_progress() >= 1.0,
			", ".join(texts))
	await layout_checks("feeding")
	await no_input_leak()
	o.ui.tap()
	await t.frames(3)
	t.check("feed_returns_control", o.stage == "" and g.cinematic == "" and p.controls_enabled and not g.cam.cinematic and o.ui.card_kind() == "", "")
	# Once only.
	p.health = mx - 1
	var f2 := jelly(1.0)
	await t.frames(20)
	g._eat(p, f2)
	await t.frames(5)
	t.check("feed_once_only", o.stage == "" and g.cinematic == "" and o.objective == "", "stage '%s'" % o.stage)
	# Continue after the lesson: no frond emptied.
	p.restore_full()
	o.on_play_started(true)
	t.check("feed_continue_after_lesson_full_health", p.health == mx and not o.run_frond, "%d/%d" % [p.health, mx])
	await all_done()


## While a card is up, a touch on the HUD's buttons does nothing in the game.
## Owner, 2026-10-01: the first jellyfish in view starts the food lesson (red ring, centred on it), even with a
## parasite in view too; a parasite lesson already under way is not interrupted by one.
func feed_first() -> void:
	await reset(["intro", "starfish"])
	var par := a_parasite(0)
	if par == null:
		par = a_parasite(1)
	if par == null:
		# (In the full suite, earlier tests have cleared these balls: check it in a fresh process.)
		if Settings.test_args.has("onb-fresh"):
			t.check("feed_first_has_a_parasite", false, "none in a fresh world")
			return
		var tag := str(Time.get_ticks_usec())
		var code := _child("_test_onb_feed_first", ["--onb-fresh=1", "--onboarding=fresh", "--run-save=" + ProjectSettings.globalize_path("user://onb_ff_run_%s.json" % tag),
				"--gill-save=" + ProjectSettings.globalize_path("user://onb_ff_gill_%s.json" % tag)])
		t.check("feed_first_fresh_world", code == 0, "fresh process exited %d" % code)
		return
	p.invuln_t = 999.0
	await face(par, 9.0)
	if p.health == p.max_health:
		p.health -= 1
	var f := jelly(3.0)
	# (Facing it already armed the parasite lesson; once the camera has settled with the jellyfish in
	# view, drop that so both are in view at the next scan.)
	await wait_until(func() -> bool: return o.visible_to_player(f.global_position, Onboarding.FOOD_SEE_M), 2.0)
	o._set_objective("")
	var on := await wait_until(func() -> bool: return o.objective == "feeding", 2.0)
	await t.frames(2)
	t.check("feed_first_jelly_beats_parasite", on and o.food_target == f and o.ui._marker.color == UiStyle.DANGER
			and o._marker_pos().distance_to(f.global_position) < 0.001,
			"objective '%s'; done(feeding) %s, hp %d/%d, food ok %s, food visible %s at %.1f m" % [o.objective, o.done("feeding"), p.health, p.max_health,
			o._food_ok(f), o.visible_to_player(f.global_position, Onboarding.FOOD_SEE_M), f.global_position.distance_to(p.global_position)])
	# Mid-parasite lesson: a jellyfish coming into view does not switch it.
	f.queue_free()
	p.ball.foods.erase(f)
	await face(par, 6.0)
	var pon := await wait_until(func() -> bool: return o.objective == "parasite", 2.0)
	if pon:
		var f2 := jelly(3.0)
		await t.frames(20)
		t.check("feed_first_parasite_lesson_not_interrupted", o.objective == "parasite", "objective '%s'" % o.objective)
		f2.queue_free()
		p.ball.foods.erase(f2)
	p.invuln_t = 0.0


func no_input_leak() -> void:
	var b: Dictionary = g.hud.button_info()["jump"]
	var ev := InputEventScreenTouch.new()
	ev.index = 3
	ev.position = b["c"]
	ev.pressed = true
	Input.parse_input_event(ev)
	await t.frames(2)
	var leaked := Input.is_action_pressed("jump")
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await t.frames(2)
	t.check("onb_card_no_input_leak", not leaked and o.ui.waiting_for_tap(), "")



## Runs the parasite lesson in a fresh process (a new run and profile) and reports its checks here.
func _parasite_fresh(name_: String) -> void:
	var tag := str(Time.get_ticks_usec())
	var code := _child("_test_onb_parasite", ["--onb-fresh=1", "--onboarding=fresh", "--run-save=" + ProjectSettings.globalize_path("user://onb_par_run_%s.json" % tag),
			"--gill-save=" + ProjectSettings.globalize_path("user://onb_par_gill_%s.json" % tag)])
	t.check(name_, code == 0, "fresh process exited %d" % code)

# --- Lesson 2: the first parasite ------------------------------------------------------------------

func parasite() -> void:
	await reset(["intro", "feeding", "starfish"])
	var par := a_parasite(0)
	if par == null:
		par = a_parasite(1)
	if par == null:
		# (In the full suite, earlier tests have cleared these balls: run the lesson in a fresh
		# process with a new run and profile, and report its checks here.)
		await _parasite_fresh("parasite_lesson_has_a_parasite")
		return
	await face(par, 6.0)
	var on := await wait_until(func() -> bool: return o.objective == "parasite", 2.0)
	if not on and not Settings.test_args.has("onb-fresh"):
		# (Earlier suite tests can leave this ball's parasites roused, so the chosen one rushes in
		# out of clear view: a player's first parasite is met in a fresh world, so check it there.)
		t.log_line("parasite lesson: not armed in the shared process (state from earlier tests); rerunning fresh")
		await _parasite_fresh("parasite_lesson_fresh_world")
		return
	t.check("parasite_objective_when_visible", on and o.parasite_target == par and o.ui.objective_text() == Onboarding.OBJ_PARASITE and g.hud.prompts.has("swipe")
			and o._marker_pos() != Vector3.INF, "objective '%s'; state %s, cinematic '%s', player %s, controls %s, parasite at %.1f m, seen %s"
			% [o.objective, g.state, g.cinematic, p.state, p.controls_enabled, par.global_position.distance_to(p.global_position),
			o.visible_to_player(par.global_position + par.ball.up_at(par.global_position) * 0.3, Onboarding.PARASITE_SEE_M, par)])
	# Owner, 2026-10-01: the parasite's ring is red and sits on the middle of its body.
	await t.frames(2)
	t.check("parasite_ring_red_and_centred", o.ui._marker.color == UiStyle.DANGER
			and o._marker_pos().distance_to(par.body_center()) < 0.001, "colour %s" % o.ui._marker.color)
	t.check("parasite_gill_never_frozen", p.controls_enabled and g.cinematic == "", "")
	# The tutorial's own swipe prompt does not show as well.
	t.check("parasite_no_duplicate_prompt", not g.prompts_active.has("swipe"), str(g.prompts_active))
	var b := par.ball
	var r0 := b.restoration
	var done0 := b.events_done
	kill(par)
	t.check("parasite_kill_applied_at_once", not par.is_alive() and b.events_done == done0 + 1 and b.restoration > r0 and o.done("parasite")
			and on_disk().has("parasite"), "%.3f -> %.3f" % [r0, b.restoration])
	t.check("parasite_staged", o.stage == "kill" and b.staging() and g.cinematic == "lesson" and not p.controls_enabled, "stage '%s'" % o.stage)
	var center: Vector3 = o._kill["center"]
	var outer: float = o._kill["outer"]
	# Mid-way: the front has passed the middle but not the edge.
	await t.seconds(Onboarding.RISE_S + Onboarding.REVEAL_S * 0.4)
	# Along eight spokes from the kill: inside the front drawn as it truly is, ahead of it still as before.
	var inside_ok := true
	var held := 0
	var fr := MossBall.frame_at(center, 0.0)
	for k in 8:
		var axis := fr.x.rotated(center, TAU * k / 8.0)
		for j in 12:
			var a := outer * (j + 0.5) / 12.0
			var dpt := center.rotated(axis, a)
			if a < b.stage_reveal - 0.05:
				inside_ok = inside_ok and absf(b.shown_health_at(dpt) - b.health_at(dpt)) < 0.01
			elif a > b.stage_reveal and b.shown_health_at(dpt) < b.health_at(dpt) - 0.05:
				held += 1
	var mid_ok := b.stage_reveal > 0.05 and b.stage_reveal < outer and inside_ok and held > 0
	t.check("parasite_restoration_spreads", mid_ok, "front %.3f of %.3f rad; inside true %s; %d points ahead still drawn as before" % [b.stage_reveal, outer, inside_ok, held])
	var gill_seen := g.cam.is_position_in_frustum(p.body_center())
	var up := b.up_at(p.global_position)
	var raised := (g.cam.global_position - p.global_position).dot(up) > 4.0
	t.check("parasite_camera_raised_keeps_gill", gill_seen and raised and g.cam.is_position_in_frustum(b.surface_point(center)),
			"camera %.1f m above him" % (g.cam.global_position - p.global_position).dot(up))
	# Damage cannot reach him while the moment has his controls.
	var hp := p.health
	p.invuln_t = 0.0
	p.take_damage(1, p.global_position + p.facing)
	t.check("parasite_stage_no_damage", p.health == hp, "")
	var carded := await wait_until(func() -> bool: return o.ui.waiting_for_tap(), Onboarding.REVEAL_S + 3.0)
	var texts: Array[String] = []
	for l in o.ui.panel().find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	t.check("parasite_card_after_reveal", carded and texts.has(Onboarding.KILL_TITLE) and texts.has(Onboarding.KILL_BODY[0]) and not b.staging(), ", ".join(texts))
	await layout_checks("parasite")
	o.ui.tap()
	await t.frames(2)
	t.check("parasite_camera_returns", o.stage == "" and g.cinematic == "" and p.controls_enabled and not g.cam.cinematic,
			"stage '%s', cinematic '%s', controls %s, player %s, cam.cinematic %s, cine weight %.2f, card '%s', last end '%s'" % [o.stage, g.cinematic,
			p.controls_enabled, p.state, g.cam.cinematic, g.cam._cine_weight, o.ui.card_kind(), o.last_end])
	await t.seconds(1.2)
	t.check("parasite_camera_back_smoothly", g.cam._cine_weight < 0.05, "%.2f; cinematic '%s', cam.cinematic %s, player %s" % [g.cam._cine_weight,
			g.cinematic, g.cam.cinematic, p.state])
	# Once only: the next kill plays at normal speed.
	var par2 := a_parasite(b.index)
	if par2 != null:
		await face(par2, 5.0)
		kill(par2)
		await t.frames(3)
		t.check("parasite_once_only", o.stage == "" and not b.staging() and g.cinematic != "lesson", "stage '%s'" % o.stage)
	await all_done()


# --- Lesson 3: the first Red Starfish ----------------------------------------------------------------

func starfish() -> void:
	await reset(["intro", "feeding", "parasite"])
	await home(0)
	var s: Starfish = null
	for st in g.starfish.stars:
		if not st.collected:
			s = st
			break
	if s == null:
		t.check("starfish_card_has_a_starfish", false, "none left")
		return
	var cam_before := g.cam.cinematic
	g.starfish.collect(s)
	await t.frames(3)
	var texts: Array[String] = []
	for l in o.ui.panel().find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	var want := [Onboarding.STAR_TITLE] + Onboarding.STAR_BODY
	var all_text := true
	for w in want:
		all_text = all_text and texts.has(w)
	t.check("starfish_card_copy", o.ui.waiting_for_tap() and all_text and o.ui.button().text == "Got it", ", ".join(texts))
	t.check("starfish_card_no_camera_staging", not g.cam.cinematic and not cam_before and g.cinematic == "lesson", "")
	t.check("starfish_flag_persisted", on_disk().has("starfish"), "")
	await layout_checks("starfish")
	o.ui.tap()
	await t.frames(2)
	t.check("starfish_card_dismissed", o.ui.card_kind() == "" and g.cinematic == "" and p.controls_enabled, "")
	var s2: Starfish = null
	for st in g.starfish.stars:
		if not st.collected and st != s:
			s2 = st
			break
	if s2 != null:
		g.starfish.collect(s2)
		await t.frames(3)
		t.check("starfish_once_only", o.ui.card_kind() == "" and g.cinematic == "", "")
	await all_done()


# --- Soft-lock exits ---------------------------------------------------------------------------------

func softlock() -> void:
	# Pause during the staged restoration: ends cleanly, moss drawn as it truly is, control back.
	await _start_kill_stage()
	if o.stage == "kill":
		var b: MossBall = o._kill["ball"]
		await t.seconds(1.5)
		g.pause_menu.open()
		await t.frames(3)
		var ended := o.stage == "" and not b.staging() and g.cinematic == "" and o.last_end == "pause"
		g.pause_menu.close()
		await t.frames(3)
		t.check("softlock_pause_ends_stage", ended and p.controls_enabled and o.done("parasite"), "last end '%s'" % o.last_end)
	# The app backgrounded during a card.
	await _start_star_card()
	if o.ui.waiting_for_tap():
		g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		await t.frames(2)
		g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		await t.frames(2)
		t.check("softlock_background_ends_card", o.stage == "" and o.ui.card_kind() == "" and p.controls_enabled and o.last_end == "background", o.last_end)
	# The hard time cap: a card nobody answers is given back.
	await _start_star_card()
	if o.stage != "":
		o.stage_t = Onboarding.STAGE_CAP - 0.1
		await t.seconds(0.3)
		t.check("softlock_time_cap", o.stage == "" and o.ui.card_kind() == "" and p.controls_enabled and o.last_end == "cap", o.last_end)
	# Leaving play (to the title) mid-moment.
	await _start_feed_stage()
	if o.stage != "":
		g.state = "title"
		await t.frames(3)
		var ok := o.stage == "" and p.model.health == p.health
		g.state = "play"
		g._end_cinematic()
		t.check("softlock_leaving_play_ends_stage", ok and o.done("feeding"), o.last_end)
	# Interrupted before its message: the lesson is done and never replayed.
	await t.frames(2)
	t.check("softlock_interrupted_is_done", o.done("feeding") and o.done("parasite") and o.done("starfish"), "")
	# Death during the interactive objective: the objective waits, then returns.
	await reset(["intro", "feeding", "starfish"])
	var par := a_parasite(0)
	if par == null:
		par = a_parasite(1)
	if par != null:
		await face(par, 6.0)
		await wait_until(func() -> bool: return o.objective == "parasite", 2.0)
		p.invuln_t = 0.0
		p.health = 1
		p.take_damage(1, par.global_position)
		var hidden := await wait_until(func() -> bool: return o.objective == "", 2.0)
		var back := await wait_until(func() -> bool: return g.cinematic == "" and p.state == "normal", 8.0)
		t.check("softlock_death_during_objective", hidden and back and p.controls_enabled and not o.done("parasite"), "cinematic '%s'" % g.cinematic)
	# Ball change during the feeding objective: the target is let go (it can be found again).
	await reset(["intro", "parasite", "starfish"])
	await home(0)
	p.health = p.max_health - 1
	var f := jelly(5.0)
	await wait_until(func() -> bool: return o.objective == "feeding", 2.0)
	await home(1)
	await t.seconds(0.5)
	t.check("softlock_ball_change_releases_target", o.objective != "feeding" or o.food_target != f, "objective '%s'" % o.objective)
	t.check("softlock_target_released", is_instance_valid(f) and f.anchor == Vector3.INF, "")
	# Normal repopulation never removes the target: the field refills around it.
	await all_done()


func _start_kill_stage() -> void:
	await reset(["intro", "feeding", "starfish"])
	var par := a_parasite(0)
	if par == null:
		par = a_parasite(1)
	if par == null:
		# (Late in the full suite every parasite near the start is gone: a stand-in where one of
		# ball 1's lived, in its zone, so the staged lesson always has a kill to stage.)
		var b0: MossBall = g.balls[0]
		if b0.parasites.is_empty():
			return
		var was: Parasite = b0.parasites[0]
		par = Parasite.new()
		par.setup(b0, was.kind, was.zone_id, was.spawn_dir, 9.0, was.spawn_h)
		b0.add_child(par)
		b0.parasites.append(par)
		await t.frames(3)
	await face(par, 5.0)
	kill(par)
	await t.frames(2)


func _start_star_card() -> void:
	await reset(["intro", "feeding", "parasite"])
	o._begin("star", "starfish", false)
	o._card(Onboarding.STAR_TITLE, Onboarding.STAR_BODY)
	o._mark("starfish")
	await t.frames(2)


func _start_feed_stage() -> void:
	await reset(["intro", "parasite", "starfish"])
	await home(0)
	p.health = p.max_health - 1
	var f := jelly(1.0)
	await t.frames(5)
	g._eat(p, f)
	await t.frames(2)


# --- Save / load and close / reopen mid-lesson (two processes) -----------------------------------------

func relaunch() -> void:
	var run_path := ProjectSettings.globalize_path("user://onb_relaunch_run.json")
	var gill_path := ProjectSettings.globalize_path("user://onb_relaunch_gill.json")
	RunSave.erase(run_path)
	GillProgress.erase(gill_path)
	var a := _child("_phase_onb_write", ["--run-save=" + run_path, "--gill-save=" + gill_path, "--onboarding=fresh"])
	var b := _child("_phase_onb_read", ["--run-save=" + run_path, "--gill-save=" + gill_path, "--onboarding=player"])
	t.check("onb_relaunch_children_ran", a == 0 and b == 0, "%d %d" % [a, b])
	RunSave.erase(run_path)
	GillProgress.erase(gill_path)


## First launch: a new player's first run. The feeding objective is up; then the first parasite
## dies and, mid-way through its staged restoration, the app is closed (the run saved as quitting does).
func phase_write() -> void:
	o._mark("starfish")   # (No starfish card in the way of what this phase checks.)
	t.check("write_new_player", not o.done("feeding") and not o.done("parasite") and o.run_frond and p.health == p.max_health - 1,
			"hp %d/%d" % [p.health, p.max_health])
	await home(0)
	p.invuln_t = 999.0
	var f := jelly(5.0)
	var on := await wait_until(func() -> bool: return o.objective == "feeding", 2.0)
	t.check("write_feeding_objective_up", on, "")
	var par := g.balls[0].parasites[0] as Parasite
	await face(par, 5.0)
	kill(par)
	await t.seconds(2.0)
	t.check("write_closed_mid_stage", o.stage == "kill" and g.balls[0].staging(), "stage '%s'" % o.stage)
	g.save_run()


## Second launch: Continue. The interrupted parasite lesson is done and not replayed; its kill and
## restoration are in the run; the feeding lesson is still to come, the frond still empty for it.
func phase_read() -> void:
	t.check("read_parasite_done_not_replayed", o.done("parasite") and o.stage == "" and not g.balls[0].staging(), "")
	t.check("read_kill_kept", not (g.balls[0].parasites[0] as Parasite).is_alive() and g.run_save.earned().has(g.balls[0].parasites[0].get_meta("completion_id", "")), "")
	t.check("read_feeding_still_pending", not o.done("feeding") and o.run_frond and p.health == p.max_health - 1, "hp %d/%d" % [p.health, p.max_health])
	g._enter_title()
	await t.frames(5)
	g.title._on_play()
	await t.frames(5)
	t.check("read_continue_no_intro", o.ui.card_kind() == "" and g.state == "play", "")
	await home(0)
	p.invuln_t = 999.0
	var f := jelly(5.0)
	var on := await wait_until(func() -> bool: return o.objective == "feeding", 2.0)
	t.check("read_feeding_objective_rearms", on and o.food_target == f, "")
	g._eat(p, f)
	t.check("read_feeding_lesson_plays", o.stage == "feed" and o.done("feeding"), o.stage)


# --- Restoration equality (two processes: staged and not) --------------------------------------------

func restoration_equal() -> void:
	var dumps := []
	for mode in ["fresh", "done"]:
		var path := ProjectSettings.globalize_path("user://onb_kill_%s.json" % mode)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		var code := _child("_phase_onb_kill", ["--onboarding=" + mode, "--dump=" + path])
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		dumps.append(d if d is Dictionary else {})
		t.check("onb_kill_child_%s" % mode, code == 0 and d is Dictionary, "exit %d" % code)
	if dumps[0].is_empty() or dumps[1].is_empty():
		return
	var s: Dictionary = dumps[0]
	var n: Dictionary = dumps[1]
	t.check("onb_kill_staged_vs_not", bool(s["staged"]) and not bool(n["staged"]), "staged %s / %s" % [s["staged"], n["staged"]])
	var diff: Array[String] = []
	for k in s:
		if k == "staged" or k == "shown":
			continue
		if JSON.stringify(s[k]) != JSON.stringify(n.get(k)):
			diff.append(k)
	t.check("onb_kill_restoration_identical", diff.is_empty() and s.size() == n.size(),
			"differs: %s; restoration %s, completion %s, map %s" % [diff, s["after"]["restoration"], s["after"]["completion"], str(s["settled"]["map"]).left(8)])
	t.check("onb_kill_presentation_differed", float(s["shown"]) < float(n["shown"]) - 0.05,
			"mean drawn health round the kill 1 s in: staged %.2f, normal %.2f" % [float(s["shown"]), float(n["shown"])])


## In the child: the tutorial's parasite killed the same way at the same moment; the true state
## right after the kill and once everything has settled, written to --dump.
func phase_kill() -> void:
	o._mark("starfish")   # (No starfish card in the way: only the kill differs between the two.)
	p.restore_full()
	var b := g.balls[0]
	var par := b.parasites[0] as Parasite
	await face(par, 5.0)
	await t.frames(30)
	var pos := par.global_position
	kill(par)
	var out := {"staged": b.staging()}
	out["after"] = _state(b)
	# The edge of the restored area as drawn one second in (the presentation, which may differ).
	await t.seconds(1.0)
	var up := b.up_at(pos)
	# The mean drawn health over the area round the kill (eight spokes out to 16 degrees).
	var sum := 0.0
	var tru := 0.0
	var fr := MossBall.frame_at(up, 0.0)
	for k in 8:
		var axis := fr.x.rotated(up, TAU * k / 8.0)
		for j in 8:
			var dpt := up.rotated(axis, deg_to_rad(2.0 * (j + 1)))
			sum += b.shown_health_at(dpt)
			tru += b.health_at(dpt)
	out["shown"] = sum / 64.0
	t.check("kill_probe", true, "staging %s, front %.4f of %.4f rad; mean drawn %.3f, true %.3f" % [b.staging(), b.stage_reveal, b.stage_outer, sum / 64.0, tru / 64.0])
	await t.seconds(14.0)
	if o.ui.waiting_for_tap():
		o.ui.tap()
	await t.seconds(1.0)
	out["settled"] = _state(b)
	var f := FileAccess.open(str(Settings.test_args.get("dump", "user://onb_kill.json")), FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	t.check("kill_dumped", true, "staged %s" % out["staged"])


func _state(b: MossBall) -> Dictionary:
	var heals := []
	for i in b.heals.size():
		heals.append([snappedf(b.heals[i].x, 1e-5), snappedf(b.heals[i].y, 1e-5), snappedf(b.heals[i].z, 1e-5), snappedf(b.heal_targets[i], 1e-5), snappedf(b.heal_speed[i], 1e-5)])
	var zones := {}
	for z in b.zones:
		zones[z] = [b.zones[z]["done"], b.zones[z]["total"], b.zones[z]["completed"]]
	var earned: Array = g.run_save.earned().keys()
	earned.sort()
	return {"restoration": snappedf(b.restoration, 1e-6), "events_done": b.events_done, "completed": b.completed, "zones": zones,
			"heals_growing": heals.size(), "earned": earned, "completion": snappedf(g.completion_percent(), 1e-6),
			"map": img_md5(b.health_img), "kills": g.stats["kills"]}
