extends RefCounted
## Hot Attic Games application infrastructure (ledger row 38): OTA discovery on resume, the
## "Please wait, applying update" activation modal, About / Copy diagnostics and the studio splash.
## Runs inside the unit suite (--only=_test_hag_infra).

const UA := preload("res://scripts/core/update_activation.gd")
const SoftRestart := preload("res://scripts/core/soft_restart.gd")

var t
var g: Game


func _init(runner) -> void:
	t = runner
	g = runner.g


func run() -> void:
	_test_resume_check_wall_clock()
	_test_activation_states()
	await _test_activation_modal()
	await _test_activation_no_duplicate()
	_test_app_info_pure()
	await _test_about_page()
	await _test_studio_splash()


## The resume check measures its gap on the wall clock (the engine clock stops while the phone
## sleeps), counts every earlier check, and survives a clock that went backwards or a bad stamp.
func _test_resume_check_wall_clock() -> void:
	var now := Time.get_unix_time_from_datetime_string("2026-10-03T12:00:00")
	var gap := 15 * 60
	var cases := [["", true], ["2026-10-03T11:59:00Z", false], ["2026-10-03T11:45:00Z", true],
			["2026-10-02T23:00:00Z", true], ["2026-10-03T12:30:00Z", true], ["garbage", true]]
	var bad: Array[String] = []
	for c in cases:
		if AutoUpdate.resume_check_due(now, c[0], gap) != c[1]:
			bad.append("%s -> %s" % [c[0], not c[1]])
	t.check("hag_resume_check_wall_clock", bad.is_empty(), ", ".join(bad))


## The modal belongs to activation only: idle, checking, downloading, failed, rejected,
## incompatible, offline and up to date never show it; an update staged for later does not either.
## Activation starts once, a second start while it runs is refused, and it ends (success or
## failure) or expires after SAFETY_MS.
func _test_activation_states() -> void:
	var base := {"ota_enabled": true, "disabled": false, "applying": false, "activation": "", "active_id": "dev-000010",
			"pending_id": "", "ready_id": "", "updater_status": "unchecked", "has_available": false}
	var bad: Array[String] = []
	for st in ["unchecked", "checking", "downloading", "available", "failed", "rejected", "incompatible", "offline", "up_to_date", "downloaded"]:
		var p := UA.phase(base.merged({"updater_status": st}, true))
		if UA.shows_modal(p):
			bad.append("%s shows it (%s)" % [st, p])
	for extra in [{"pending_id": "dev-000011"}, {"ready_id": "dev-000011"}, {"activation": "failed"}, {"activation": "done"},
			{"ota_enabled": false}, {"disabled": true}]:
		var p := UA.phase(base.merged(extra, true))
		if UA.shows_modal(p):
			bad.append("%s shows it (%s)" % [extra, p])
	var applying := UA.phase(base.merged({"applying": true, "pending_id": "dev-000011"}, true))
	if not UA.shows_modal(applying):
		bad.append("activation does not show it (%s)" % applying)
	var named := [UA.phase(base.merged({"updater_status": "up_to_date"}, true)), UA.phase(base.merged({"updater_status": "available"}, true)),
			UA.phase(base.merged({"pending_id": "dev-000011"}, true)), applying, UA.phase(base.merged({"updater_status": "failed"}, true))]
	if named != ["CURRENT", "AVAILABLE", "STAGED", "APPLYING", "FAILED"]:
		bad.append("states %s" % [named])
	t.check("hag_activation_modal_only_when_applying", bad.is_empty(), "; ".join(bad))
	var saved: Variant = Engine.get_meta(UA.META, null)
	if Engine.has_meta(UA.META):
		Engine.remove_meta(UA.META)
	var first := UA.begin("dev-000011", 1000)
	var dup := UA.begin("dev-000012", 1500)
	var running := UA.is_applying(1500) and str(UA.state()["ota_id"]) == "dev-000011"
	UA.finish(true)
	var cleared_ok: bool = not UA.is_applying(1600) and UA.state()["state"] == "done"
	UA.begin("dev-000012", 2000)
	UA.finish(false, "native layer did not mount it")
	var cleared_fail: bool = not UA.is_applying(2100) and UA.state()["state"] == "failed"
	UA.begin("dev-000013", 3000)
	var expires := UA.is_applying(3000 + UA.SAFETY_MS - 1) and not UA.is_applying(3000 + UA.SAFETY_MS)
	var after_expiry := UA.begin("dev-000014", 3000 + UA.SAFETY_MS)
	t.check("hag_activation_once_and_cleared", first and not dup and running and cleared_ok and cleared_fail and expires and after_expiry,
			"first %s dup %s running %s ok %s fail %s expires %s again %s" % [first, dup, running, cleared_ok, cleared_fail, expires, after_expiry])
	if Engine.has_meta(UA.META):
		Engine.remove_meta(UA.META)
	if saved != null:
		Engine.set_meta(UA.META, saved)


## The modal: exactly the text, an indeterminate indicator, Mote's panel, input blocked, on top of
## everything game-side; its safety timer turns it into a short message and removes it.
func _test_activation_modal() -> void:
	var tree := g.get_tree()
	var m := UA.show_modal(tree, 0.4)
	await t.frames(2)
	var msg := m.find_child("Message", true, false) as Label
	var bar := m.find_child("Indicator", true, false) as ProgressBar
	var bg := m.find_child("Backdrop", true, false) as ColorRect
	var panel := m.find_child("Panel", true, false) as PanelContainer
	var screen := bg.get_viewport_rect()
	t.check("hag_modal_text_indicator_blocks_input", msg != null and msg.text == "Please wait, applying update" and bar != null and bar.indeterminate
			and bar.is_visible_in_tree() and bg.mouse_filter == Control.MOUSE_FILTER_STOP and m.layer > 100
			and screen.encloses(panel.get_global_rect()) and bg.get_global_rect().size == screen.size and bg.theme != null,
			"text '%s', panel %s in %s" % [msg.text if msg != null else "?", panel.get_global_rect(), screen])
	var second := UA.show_modal(tree, 0.4)
	await t.frames(1)
	var one := tree.root.get_children().filter(func(n: Node) -> bool: return n.name == UA.NODE_NAME).size() == 1
	t.check("hag_modal_single_instance", one and is_instance_valid(second) and not is_instance_valid(m), "")
	await t.seconds(0.6)
	var msg2 := second.find_child("Message", true, false) as Label
	var timed_out: bool = is_instance_valid(second) and msg2.text == UA.TIMEOUT_TEXT and not (second.find_child("Indicator", true, false) as Control).visible
	await t.seconds(0.6)
	t.check("hag_modal_safety_timeout_never_hangs", timed_out and not is_instance_valid(second) and UA.modal(tree) == null, "message then removed")


## SoftRestart.apply refuses to start while an activation runs: no second modal, nothing recorded.
func _test_activation_no_duplicate() -> void:
	var saved_path: String = SoftRestart.record_path
	SoftRestart.record_path = OS.get_user_data_dir().path_join("hag_dup_%d.json" % Time.get_ticks_usec())
	var saved: Variant = Engine.get_meta(UA.META, null)
	if Engine.has_meta(UA.META):
		Engine.remove_meta(UA.META)
	UA.begin("dev-000020")
	var why: String = await SoftRestart.apply({"ota_id": "dev-000021"}, "title", func() -> String: return "")
	t.check("hag_no_duplicate_activation", why == "an update is already being applied" and UA.modal(g.get_tree()) == null
			and not SoftRestart.was_attempted("dev-000021") and str(UA.state()["ota_id"]) == "dev-000020", why)
	if Engine.has_meta(UA.META):
		Engine.remove_meta(UA.META)
	if saved != null:
		Engine.set_meta(UA.META, saved)
	DirAccess.remove_absolute(SoftRestart.record_path)
	SoftRestart.record_path = saved_path


func _test_app_info_pure() -> void:
	var bad: Array[String] = []
	for c in [["/data/user/0/com.verbal76.axolotl/files", "com.verbal76.axolotl"], ["/data/data/com.verbal76.axolotl/files/", "com.verbal76.axolotl"],
			["/data/user/10/com.example.game/files", "com.example.game"], ["/home/x/.local/share/godot/app_userdata/Mote", ""],
			["/storage/emulated/0/Android/data/com.verbal76.axolotl/files", ""], ["", ""]]:
		if AppInfo.package_from_data_dir(c[0]) != c[1]:
			bad.append("%s -> '%s'" % [c[0], AppInfo.package_from_data_dir(c[0])])
	for c in [[-1, 36, "UNVERIFIED"], [36, 36, "YES"], [37, 36, "YES"], [35, 36, "NO"], [34, 0, "UNVERIFIED"]]:
		if AppInfo.play_api_compliant(c[0], c[1]) != c[2]:
			bad.append("compliance %s" % [c])
	t.check("hag_app_info_package_and_play_rules", bad.is_empty(), "; ".join(bad))


## About: a few lines on the page; the standard report (every field present, unknowns said as
## such) and the native diagnostics under Technical and on the clipboard; nothing secret or
## personal; buttons inside the panel, finger-sized, apart; no scrolling until Technical is opened.
func _test_about_page() -> void:
	var r := AppInfo.report_text()
	var missing: Array[String] = []
	for k in ["Captured at: ", "App name: Mote", "Package id: ", "Version name: ", "Version code: ", "Native runtime: " + Boot.identity()["runtime_id"],
			"Build identity: ", "Source SHA (running code): ", "Channel: ", "OS: ", "API level: ", "Model: ", "Locale: ",
			"Updates enabled: ", "Runtime compatibility: ", "Current OTA: ", "Running source: ", "OTA source SHA: ", "OTA PCK SHA-256: ",
			"Last check: ", "Update state: ", "Target SDK: " + AppInfo.NOT_EXPOSED, "Play required target API: 36",
			"PLAY API COMPLIANT: UNVERIFIED"]:
		if not r.contains(k):
			missing.append(k)
	t.check("hag_report_has_every_field", missing.is_empty(), "missing: %s" % [missing])
	var copy := AppInfo.copy_text()
	var leaks: Array[String] = []
	for s in ["PRIVATE KEY", "BEGIN PUBLIC KEY", "PASSWORD", "KEYSTORE", "password"]:
		if copy.contains(s):
			leaks.append(s)
	var home := OS.get_environment("HOME")
	if home.length() > 1 and copy.contains(home):
		leaks.append("home directory")
	t.check("hag_copy_text_plain_no_secrets", leaks.is_empty() and copy.begins_with("MOTE ABOUT / DIAGNOSTICS") and copy.contains("MOTE DIAGNOSTICS"), "found %s" % [leaks])
	var dp: DiagnosticsPage = g.diagnostics
	dp.open()
	await t.frames(3)
	var panel := dp._panel.get_global_rect()
	var screen := dp._root.get_viewport_rect()
	var bad: Array[String] = []
	if not screen.encloses(panel):
		bad.append("panel %s off screen %s" % [panel, screen])
	if dp._tech.is_visible_in_tree():
		bad.append("technical text open by default")
	var rects: Array[Rect2] = []
	for n in dp._panel.find_children("*", "Button", true, false):
		var b := n as Button
		if not b.is_visible_in_tree():
			continue
		var br := b.get_global_rect()
		if not panel.encloses(br) or br.size.y < 56.0:
			bad.append("%s %s" % [b.name, br])
		for o in rects:
			if o.intersects(br):
				bad.append("%s overlaps" % b.name)
		rects.append(br)
	# With Install showing too (an update waiting on the title), the button row still fits.
	var row := dp._install.get_parent() as Control
	dp._install.visible = true
	var row_w := row.get_combined_minimum_size().x
	dp._install.visible = false
	if row_w > row.size.x + 0.5:
		bad.append("button row with Install needs %.0f of %.0f" % [row_w, row.size.x])
	var lines := dp._detail.text.split("\n")
	if lines.size() > 6 or not dp._detail.text.contains("Updates: ") or not panel.encloses(dp._detail.get_global_rect()):
		bad.append("about block %s" % [lines])
	t.check("hag_about_concise_fits_no_scroll", bad.is_empty(), "; ".join(bad))
	(dp._panel.find_child("TechnicalToggle", true, false) as Button).pressed.emit()
	await t.frames(2)
	var tech_ok: bool = dp._tech.is_visible_in_tree() and dp._text.text.contains("PLAY API COMPLIANT") and dp._text.text.contains("MOTE DIAGNOSTICS")
	(dp._panel.find_child("Copy", true, false) as Button).pressed.emit()
	await t.frames(1)
	var copied: bool = dp._detail.text.contains("Diagnostics copied.")
	if DisplayServer.get_name() != "headless":
		copied = copied and DisplayServer.clipboard_get().begins_with("MOTE ABOUT / DIAGNOSTICS")
	dp.close()
	await t.frames(1)
	t.check("hag_about_technical_and_copy", tech_ok and copied, "technical %s, copied %s" % [tech_ok, copied])


## The studio splash: only on a genuine launch (not a scene reload, an in-process update or a test
## run), only when the canonical logo is in the build (skipped otherwise: no placeholder), black,
## logo centred and contain-fitted with its aspect kept, above the loading screen, input blocked,
## gone after about 1.5 s on its own.
func _test_studio_splash() -> void:
	var bad: Array[String] = []
	var real_missing := not ResourceLoader.exists(StudioSplash.LOGO_PATH)
	var cases := [[StudioSplash.LOGO_PATH, "", false, false, "" if not real_missing else StudioSplash.MISSING],
			["res://assets/icon/splash.png", "", false, false, ""], ["res://assets/icon/splash.png", "", true, false, "not a genuine launch"],
			["res://assets/icon/splash.png", "", false, true, "not a genuine launch"], ["res://assets/icon/splash.png", "unit", false, false, "automated test run"],
			["res://branding/none.png", "", false, false, StudioSplash.MISSING]]
	for c in cases:
		var why := StudioSplash.decide(c[0], c[1], c[2], c[3])
		if (c[4] == "" and why != "") or (c[4] != "" and not why.begins_with(c[4])):
			bad.append("%s -> '%s'" % [c, why])
	t.check("hag_splash_genuine_launch_and_asset_rules", bad.is_empty(), "; ".join(bad))
	t.log_line("canonical logo %s: %s" % [StudioSplash.LOGO_PATH, "MISSING (splash skipped)" if real_missing else "present"])
	var saved_meta: Variant = Engine.get_meta(StudioSplash.META, null)
	var saved_path := StudioSplash.logo_path
	# The real asset is missing: the launch path adds nothing.
	if Engine.has_meta(StudioSplash.META):
		Engine.remove_meta(StudioSplash.META)
	StudioSplash.logo_path = "res://branding/Hot_Attic_Games_Master_Logo_absent.png"
	var none := StudioSplash.maybe_show(g, "", false)
	var skip_why := str(Engine.get_meta(StudioSplash.META, ""))
	var skipped_ok := none == null and str(Engine.get_meta(StudioSplash.META, "")).contains(StudioSplash.MISSING) and g.get_node_or_null("StudioSplash") == null
	# With an image standing in for the logo (2:1, so the aspect must be kept).
	Engine.remove_meta(StudioSplash.META)
	StudioSplash.logo_path = "res://assets/textures/room/atlas.png"
	var s := StudioSplash.maybe_show(g, "", false)
	await t.frames(2)
	var shown_ok := (s != null and s.layer > 100 and (s.get_node("Black") as ColorRect).color == Color(0, 0, 0, 1)
			and (s.get_node("Black") as Control).mouse_filter == Control.MOUSE_FILTER_STOP)
	var fit := ""
	if s != null:
		var screen := s.get_viewport().get_visible_rect()
		var r := s.drawn_rect()
		var ts := s.texture.get_size()
		var centred := r.get_center().distance_to(screen.get_center()) < 1.5
		var aspect := absf(r.size.x / r.size.y - ts.x / ts.y) < 0.01
		var contained := screen.encloses(r) and (is_equal_approx(r.size.x, s.logo.size.x) or is_equal_approx(r.size.y, s.logo.size.y))
		shown_ok = shown_ok and centred and aspect and contained
		fit = "drawn %s in %s, texture %s" % [r, screen, ts]
	var again := StudioSplash.maybe_show(g, "", false)
	# Wall time (the splash runs on it; test runs use a fixed frame rate).
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1000:
		await t.frames(1)
	var still := is_instance_valid(s)
	while Time.get_ticks_msec() - t0 < 1800:
		await t.frames(1)
	await t.frames(2)
	var gone := not is_instance_valid(s)
	t.check("hag_splash_skipped_when_logo_missing", skipped_ok, skip_why)
	t.check("hag_splash_black_centred_contain_fit", shown_ok, fit)
	t.check("hag_splash_once_per_launch_about_1_5_s", again == null and still and gone, "second %s, at 1 s %s, at 2 s gone %s" % [again, still, gone])
	StudioSplash.logo_path = saved_path
	Engine.remove_meta(StudioSplash.META)
	if saved_meta != null:
		Engine.set_meta(StudioSplash.META, saved_meta)
