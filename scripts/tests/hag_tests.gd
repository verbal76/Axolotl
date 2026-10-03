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
