class_name QualityScaler
extends Node
## Quiet thermal/performance scaling (no messages, ever). Controls, camera, character, enemies,
## hints and restoration readability are never touched; only secondary visual cost is: the ceiling
## light's shadows first, then MSAA, resolution scale, particles, vegetation density, glow and
## secondary lights.
##
## Thermal pass (owner, 2026-10-06: a tester's phone, a Galaxy A14/A23/A26-class device, got hot):
## frame RATE alone is not enough. A phone that can just hold 60 fps at full quality would otherwise
## run its GPU flat out for the whole session and heat up until it throttles. So the scaler also
## watches how busy each frame is (the GPU's and the CPU's measured milliseconds against the frame
## budget) and, when a phone stays near flat-out (HOT_LOAD) for HOT_WINDOWS in a row, steps down
## although 60 still holds, to keep headroom. Light load (COOL_LOAD) for a long while steps back up,
## never straight back into a level that ran hot (a ceiling for HOT_CEILING_S).
## A phone that cannot hold 60 even at the lowest level runs at an even 30 (smoother than an uneven
## 35-50 and about half the work); it goes back to 60 only if 60 would clearly fit.
## Menus over a paused world run at 30 too (the world behind them does not move).
## Capable phones keep full quality: none of this acts unless the phone is working hard.

var level := 0
var mote_lights := 3
var _acc := 0.0
var _frames := 0
var _low_windows := 0
var _high_windows := 0
var _hot_windows := 0
var _cool_windows := 0
var _cooldown := 0.0
var _load_sum := 0.0
var _load_n := 0
var _ms_sum := 0.0
## The highest level allowed now (a level that ran hot is not re-entered for a while), and until when.
var ceiling := 0
var _ceiling_t := 0.0
## True while the phone runs at an even 30 fps because 60 does not fit even at the lowest level.
var fps30 := false
var _fps30_entries := 0
var _fps30_fit_windows := 0
var history: Array = []
## Per 2 s window: the measured load (0..1+ of the frame budget), for diagnostics and tests.
var load_history: Array = []
var last_load := -1.0
## Tests: [gpu_ms, cpu_ms] for this frame instead of the measured ones. Empty = measure.
var measure_fn: Callable
## Tests may let the frame caps act under --test (otherwise a test run is never capped).
var caps_in_tests := false
var _fps0 := 60
var _rid: RID

## "shadow": the ceiling light's shadow distance in metres (0 = none; Expansion 6).
const LEVELS := [
	{"scale": 1.0, "specks": 420, "veg": 1.0, "glow": true, "lights": 3, "shadow": 30.0, "msaa": true},
	# (Shadows go first: they are most of what the Expansion 6 lighting costs.)
	{"scale": 0.9, "specks": 300, "veg": 0.8, "glow": true, "lights": 2, "shadow": 0.0, "msaa": true},
	{"scale": 0.8, "specks": 200, "veg": 0.6, "glow": false, "lights": 1, "shadow": 0.0, "msaa": false},
	{"scale": 0.7, "specks": 120, "veg": 0.45, "glow": false, "lights": 1, "shadow": 0.0, "msaa": false},
	# (Only a phone that needs it ever gets here: entry-level GPUs such as a Mali-G52 or Adreno 610.)
	{"scale": 0.62, "specks": 60, "veg": 0.35, "glow": false, "lights": 1, "shadow": 0.0, "msaa": false},
]
const WINDOW_S := 2.0
## Sustained share of the frame budget that counts as "running hot", and as "plenty of room".
const HOT_LOAD := 0.8
const COOL_LOAD := 0.45
const HOT_WINDOWS := 10
const COOL_WINDOWS := 30
const HOT_CEILING_S := 300.0
## At 30 fps: go back to 60 only if 60 would fit with this share of its budget.
const FPS30_FIT_LOAD := 0.6
const FPS30_FIT_WINDOWS := 45


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fps0 = Engine.max_fps if Engine.max_fps > 0 else 60
	_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_rid, true)
	# Mobile screens are dense; start slightly below native resolution for the 3D pass.
	if OS.has_feature("mobile"):
		get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	_apply()


## The frame rate the game should run at now: the project's, or 30 at the lowest level when 60
## does not fit, on the capped title, and under a paused world (menus).
func fps_cap() -> int:
	var cap := _fps0
	if fps30:
		cap = mini(cap, 30)
	var g := Game.inst
	if g != null and g.title_capped:
		cap = mini(cap, 30)
	if is_inside_tree() and get_tree().paused:
		cap = mini(cap, 30)
	return cap


func _apply_fps() -> void:
	if Settings.test_mode != "" and not caps_in_tests:
		return
	var cap := fps_cap()
	if Engine.max_fps != cap:
		Engine.max_fps = cap


## This frame's [gpu_ms, cpu_ms]: what the GPU spent on the frame, and the main thread's process,
## physics and render-submission time. 0 for a measure the platform does not give.
func _measure() -> Array:
	if measure_fn.is_valid():
		return measure_fn.call()
	# (A test run's frames are the tests' own work, not the game's: there the scaler acts on frame
	# rate alone, as it always did, unless a test feeds it measurements.)
	if Settings.test_mode != "":
		return [0.0, 0.0]
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(_rid)
	var cpu := (Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0 \
			+ RenderingServer.viewport_get_measured_render_time_cpu(_rid)
	return [gpu, cpu]


func _process(dt: float) -> void:
	_apply_fps()
	if get_tree().paused:
		return
	# (The title capped at an even 30 fps (Game._title_pacing) is not a slow frame rate: its frames
	# are never counted, and a window it interrupts starts again (ledger row 28: the cap used to step
	# quality down to the lowest level within ~16 s).)
	if Game.inst != null and Game.inst.title_capped:
		_acc = 0.0
		_frames = 0
		_low_windows = 0
		_high_windows = 0
		_load_sum = 0.0
		_load_n = 0
		return
	var m := _measure()
	var busy := maxf(float(m[0]), float(m[1]))
	if busy > 0.0:
		_ms_sum += busy
		_load_n += 1
	_acc += dt
	_frames += 1
	_cooldown = maxf(0.0, _cooldown - dt)
	_ceiling_t = maxf(0.0, _ceiling_t - dt)
	if _ceiling_t <= 0.0:
		ceiling = 0
	if _acc < WINDOW_S:
		return
	var fps := _frames / _acc
	var target := 30.0 if fps30 else float(_fps0)
	# Load: the mean busy time against the budget at the rate being run (-1: not measurable here).
	var ms := _ms_sum / _load_n if _load_n > 0 else -1.0
	var load := ms / (1000.0 / target) if ms >= 0.0 else -1.0
	last_load = load
	history.append(fps)
	load_history.append(load)
	if history.size() > 120:
		history.pop_front()
		load_history.pop_front()
	_acc = 0.0
	_frames = 0
	_ms_sum = 0.0
	_load_n = 0
	var slow := fps < target * 0.9
	if slow:
		_low_windows += 1
		_high_windows = 0
	elif fps > target - 1.0:
		_high_windows += 1
		_low_windows = 0
	else:
		_low_windows = 0
		_high_windows = 0
	var hot := load >= HOT_LOAD and not slow
	_hot_windows = _hot_windows + 1 if hot else 0
	var cool := load >= 0.0 and load < COOL_LOAD and not slow
	_cool_windows = _cool_windows + 1 if cool else 0
	# At 30: does 60 now clearly fit (the same work in half the budget)?
	if fps30:
		_fps30_fit_windows = _fps30_fit_windows + 1 if (ms >= 0.0 and ms / (1000.0 / _fps0) < FPS30_FIT_LOAD and not slow) else 0
		if _fps30_fit_windows >= FPS30_FIT_WINDOWS and _fps30_entries < 2:
			fps30 = false
			_fps30_fit_windows = 0
			_cooldown = 20.0
			_reset_windows()
		return
	var floor_level := LEVELS.size() - 1
	# Can't keep up (slow) or keeps the phone flat out (hot): one step down.
	var step_down := (_low_windows >= 2 or _hot_windows >= HOT_WINDOWS) and _cooldown <= 0.0
	if step_down and level < floor_level:
		if _hot_windows >= HOT_WINDOWS:
			ceiling = level + 1
			_ceiling_t = HOT_CEILING_S
		level += 1
		_cooldown = 6.0
		_reset_windows()
		_apply()
	elif step_down and level == floor_level:
		# Even the lowest level does not fit 60: an even 30 instead (twice, then it stays there).
		fps30 = true
		_fps30_entries += 1
		_reset_windows()
	elif level > maxi(0, ceiling) and _cooldown <= 0.0 and (_cool_windows >= COOL_WINDOWS or (load < 0.0 and _high_windows >= 15)):
		# Plenty of room for a long while (or, with nothing to measure, a steady full rate): one step up.
		level -= 1
		_cooldown = 30.0
		_reset_windows()
		_apply()


func _reset_windows() -> void:
	_low_windows = 0
	_high_windows = 0
	_hot_windows = 0
	_cool_windows = 0


func force_level(l: int) -> void:
	level = clampi(l, 0, LEVELS.size() - 1)
	_apply()


func _apply() -> void:
	var q: Dictionary = LEVELS[level]
	get_viewport().scaling_3d_scale = q["scale"] * (0.85 if OS.has_feature("mobile") else 1.0)
	var msaa := Viewport.MSAA_2X if q["msaa"] else Viewport.MSAA_DISABLED
	if get_viewport().msaa_3d != msaa:
		get_viewport().msaa_3d = msaa
	if WaterFX.inst:
		WaterFX.inst.set_speck_density(q["specks"])
	var g := Game.inst
	if g:
		for b in g.balls:
			b.set_vegetation_density(q["veg"])
		if g.aquarium and g.aquarium.sun:
			g.aquarium.sun.shadow_enabled = q["shadow"] > 0.0
			g.aquarium.sun.directional_shadow_max_distance = maxf(q["shadow"], 1.0)
		if g.env:
			g.env.glow_enabled = q["glow"]
	mote_lights = q["lights"]


## One line for the diagnostics page.
func summary() -> String:
	return "quality level %d/%d, %s, last load %s" % [level, LEVELS.size() - 1, "even 30 fps" if fps30 else "%d fps" % _fps0,
			("%.0f%%" % (last_load * 100.0)) if last_load >= 0.0 else "n/a"]
