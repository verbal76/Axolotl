extends Node
## Automated verification harness (not part of normal play). Enabled only from the command
## line:  godot --path . -- --test=<unit|playthrough|shots> [--out=<dir>]
## Every result is printed as "[TEST] PASS|FAIL <name> <detail>" and the process exits with a
## non-zero code if anything failed.

var g: Game
var out_dir := "user://test_out"
var results: Array = []
var _fails := 0


func _ready() -> void:
	g = Game.inst
	out_dir = Settings.test_args.get("out", out_dir)
	DirAccess.make_dir_recursive_absolute(out_dir)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	await frames(3)
	var suites := {"unit": "res://scripts/tests/unit_tests.gd", "playthrough": "res://scripts/tests/playthrough_bot.gd",
			"shots": "res://scripts/tests/shots.gd"}
	var script: GDScript = load(suites.get(Settings.test_mode, "")) if suites.has(Settings.test_mode) else null
	if script == null or not script.can_instantiate():
		check("load_suite_" + Settings.test_mode, false, "suite failed to load")
		finish()
		return
	await script.new().run(self)
	finish()


# --- Helpers used by the suites ----------------------------------------------------------

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func seconds(s: float) -> void:
	await frames(int(ceil(s * Engine.physics_ticks_per_second)))


func check(name_: String, ok: bool, detail := "") -> bool:
	results.append([name_, ok, detail])
	if not ok:
		_fails += 1
	print("[TEST] %s %s %s" % ["PASS" if ok else "FAIL", name_, detail])
	return ok


func log_line(s: String) -> void:
	print("[LOG] " + s)


func shot(name_: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name_ + ".png")
	img.save_png(path)
	log_line("screenshot " + path)


func finish() -> void:
	var passed := results.filter(func(r): return r[1]).size()
	print("[TEST] SUMMARY %d passed, %d failed" % [passed, _fails])
	var f := FileAccess.open(out_dir.path_join("results_%s.txt" % Settings.test_mode), FileAccess.WRITE)
	if f:
		for r in results:
			f.store_line("%s %s %s" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
		f.store_line("SUMMARY %d passed, %d failed" % [passed, _fails])
	get_tree().quit(1 if _fails > 0 else 0)
