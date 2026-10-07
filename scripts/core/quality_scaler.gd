class_name QualityScaler
extends Node
## Quiet thermal/performance scaling (no messages, ever). Controls, camera, character, enemies,
## hints and restoration readability are never touched; only secondary visual cost is: the ceiling
## light's shadows first, then resolution scale, particles, vegetation density, glow and secondary
## lights.
##
## Thermal pass (owner, 2026-10-06: a tester's phone, a Galaxy A14/A23/A26-class device, got hot):
## frame RATE alone is not enough. A phone that can just hold 60 fps at full quality would otherwise
## run flat out for the whole session and heat up until it throttles. So the scaler also watches how
## busy the game's own frame work is (process and physics milliseconds against the frame budget) and,
## when a phone stays near flat-out (HOT_LOAD) for HOT_WINDOWS in a row, steps down although 60 still
## holds, to keep headroom.
##
## v103 corrective (owner, 2026-10-07: v103 froze the owner's Pixel during play, again and again, and
## stepped its quality down on every launch although it runs the game well): no GPU frame timing
## (the GPU timestamp queries it needs are gone) and no MSAA switching mid-game (MSAA stays as the
## project sets it, always). A phone that holds 60 fps with its game work well inside the budget is
## never stepped down. Light load (COOL_LOAD) for a long while steps back up,
## never straight back into a level that ran hot (a ceiling for HOT_CEILING_S).
## A phone that cannot hold 60 even at the lowest level runs at an even 30 (smoother than an uneven
## 35-50 and about half the work); it goes back to 60 only if 60 would clearly fit.
## Menus over a paused world run at 30 too (the world behind them does not move).
## Capable phones keep full quality: none of this acts unless the phone is working hard.
##
## The player's Video setting (owner, 2026-10-06; Settings.video_mode, set_mode) picks the policy:
##  - "auto" (Automatic, recommended): all of the above.
##  - "quality": full visuals at 60 fps; load alone never steps down. Only a failsafe against severe
##    sustained overload acts (fps under QUALITY_SLOW of the target for QUALITY_SLOW_WINDOWS), and it
##    climbs back quickly once full rate holds again.
##  - "cool" (Cool/Battery): starts at, and never goes above, COOL_MIN_LEVEL (Balanced: no shadows, no
##    glow, a lower render scale), and steps down sooner (COOL_HOT_LOAD) to keep heat and battery use low.
## Every mode only changes visual cost. Gameplay, input sampling, the camera, physics ticks, attack
## timing, jump buffering and every other responsiveness system run exactly the same in all three.

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
## Tests: [unused, cpu_ms] for this frame instead of the measured ones (the first entry is kept for
## the tests' shape; there is no GPU timing). Empty = measure.
var measure_fn: Callable
## Tests may let the frame caps act under --test (otherwise a test run is never capped).
var caps_in_tests := false
var _fps0 := 60
## "auto", "quality" or "cool" (Settings.VIDEO_MODES).
var mode := "auto"

## "shadow": the ceiling light's shadow distance in metres (0 = none; Expansion 6).
const LEVELS := [
	{"scale": 1.0, "specks": 420, "veg": 1.0, "glow": true, "lights": 3, "shadow": 30.0},
	# (Shadows go first: they are most of what the Expansion 6 lighting costs.)
	{"scale": 0.9, "specks": 300, "veg": 0.8, "glow": true, "lights": 2, "shadow": 0.0},
	{"scale": 0.8, "specks": 200, "veg": 0.6, "glow": false, "lights": 1, "shadow": 0.0},
	{"scale": 0.7, "specks": 120, "veg": 0.45, "glow": false, "lights": 1, "shadow": 0.0},
	# (Only a phone that needs it ever gets here: entry-level GPUs such as a Mali-G52 or Adreno 610.)
	{"scale": 0.62, "specks": 60, "veg": 0.35, "glow": false, "lights": 1, "shadow": 0.0},
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
## Quality mode's failsafe: severe overload only (fps under this share of the target, this many windows).
const QUALITY_SLOW := 0.75
const QUALITY_SLOW_WINDOWS := 5
const QUALITY_UP_WINDOWS := 8
## Cool/Battery: the best level it allows, and its earlier thresholds.
const COOL_MIN_LEVEL := 2
const COOL_HOT_LOAD := 0.6
const COOL_COOL_LOAD := 0.3
## For the menus and diagnostics.
const TIER_NAMES := ["Full", "High", "Balanced", "Light", "Lowest"]
const MODE_NAMES := {"auto": "Automatic", "quality": "Quality", "cool": "Cool/Battery"}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fps0 = Engine.max_fps if Engine.max_fps > 0 else 60
	# Mobile screens are dense; start slightly below native resolution for the 3D pass.
	if OS.has_feature("mobile"):
		get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	level = maxi(level, min_level())
	_apply()


## Switches the policy (the Video setting). Starts it afresh, as on a cold launch with that setting:
## Automatic and Quality at full quality, Cool/Battery at its own best level. Visual cost only.
func set_mode(m: String) -> void:
	mode = m if m in MODE_NAMES else "auto"
	_reset_windows()
	_acc = 0.0
	_frames = 0
	_ms_sum = 0.0
	_load_n = 0
	ceiling = 0
	_ceiling_t = 0.0
	fps30 = false
	_fps30_entries = 0
	_fps30_fit_windows = 0
	level = min_level()
	_cooldown = 6.0
	if is_inside_tree():
		_apply()


## The best (lowest-numbered) level this mode allows.
func min_level() -> int:
	return COOL_MIN_LEVEL if mode == "cool" else 0


func hot_load() -> float:
	return COOL_HOT_LOAD if mode == "cool" else HOT_LOAD


func cool_load() -> float:
	return COOL_COOL_LOAD if mode == "cool" else COOL_LOAD


func tier_name() -> String:
	return TIER_NAMES[level]


## The active tier for the menus, e.g. "Balanced, 60 fps".
func tier_text() -> String:
	return "%s, %s" % [tier_name(), "30 fps" if fps30 else "%d fps" % _fps0]


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


## This frame's [0, cpu_ms]: the game's process and physics time (cheap engine counters; no GPU
## timing, see the class notes).
func _measure() -> Array:
	if measure_fn.is_valid():
		return measure_fn.call()
	# (A test run's frames are the tests' own work, not the game's: there the scaler acts on frame
	# rate alone, as it always did, unless a test feeds it measurements.)
	if Settings.test_mode != "":
		return [0.0, 0.0]
	var cpu := (Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	return [0.0, cpu]


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
	# (Quality: only a severe overload counts as slow; load alone never steps it down.)
	var slow := fps < target * (QUALITY_SLOW if mode == "quality" else 0.9)
	if slow:
		_low_windows += 1
		_high_windows = 0
	elif fps > target - 1.0:
		_high_windows += 1
		_low_windows = 0
	else:
		_low_windows = 0
		_high_windows = 0
	var hot := load >= hot_load() and not slow and mode != "quality"
	_hot_windows = _hot_windows + 1 if hot else 0
	var cool := load >= 0.0 and load < cool_load() and not slow
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
	var slow_n := QUALITY_SLOW_WINDOWS if mode == "quality" else 2
	var step_down := (_low_windows >= slow_n or _hot_windows >= HOT_WINDOWS) and _cooldown <= 0.0
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
	elif level > maxi(min_level(), ceiling) and _cooldown <= 0.0 and (_cool_windows >= COOL_WINDOWS or (load < 0.0 and _high_windows >= 15) \
			or (mode == "quality" and _high_windows >= QUALITY_UP_WINDOWS)):
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
	level = clampi(l, min_level(), LEVELS.size() - 1)
	_apply()


func _apply() -> void:
	var q: Dictionary = LEVELS[level]
	get_viewport().scaling_3d_scale = q["scale"] * (0.85 if OS.has_feature("mobile") else 1.0)
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
	return "video %s: quality level %d/%d (%s), %s, last load %s" % [MODE_NAMES[mode], level, LEVELS.size() - 1, tier_name(),
			"even 30 fps" if fps30 else "%d fps" % _fps0,
			("%.0f%%" % (last_load * 100.0)) if last_load >= 0.0 else "n/a"]
