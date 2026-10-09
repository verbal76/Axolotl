extends Node
## Autoload: input map, persisted player settings, haptics, touch/controller mode and
## session flags that must survive a scene reload (Restart Experience / Return to Title).

signal input_mode_changed(mode: int)
signal settings_changed
signal gill_look_changed

enum InputMode { TOUCH, PAD }

const SETTINGS_PATH := "user://settings.cfg"

var reduced_hud := false
## Shows the small run timer during play (the pause menu always shows it).
var show_run_timer := false
var haptics := true
## Swim Mode only (owner, 2026-09-30): false = flight-stick pitch (pull down to swim up); true =
## push up to swim up. Nothing else is inverted. Absent in older files (default false).
var swim_invert_y := false
## Tutorials (docs/ONBOARDING.md, owner ruling 2026-10-01): the intro and the three lessons on every
## new run. On by default, also for files from before it existed (absent = on).
var tutorials := true
var music_volume := 0.8
var sfx_volume := 0.9
var input_mode: int = InputMode.TOUCH
## The character's colours (GillLook): a morph plus fine-tuning of the body and the freckles.
var gill_morph := "pink"
var gill_body_hue := 0.0
var gill_body_bright := 1.0
var gill_dots_hue := 0.0
var gill_dots_bright := 1.0
## His pattern (GillLook.PATTERNS or "upload"), shown as markings (0) or in full colour (1),
## repeated this many times round his body.
var gill_pattern := "none"
var gill_pattern_mode := 0
var gill_pattern_size := 3
var gill_pattern_alpha := false

## Session flags (not saved to disk).
var skip_title := false
var test_mode := ""          # set from the command line: -- --test=<name>
var test_args := {}

var _pad_connected := false


## Shader globals used by the light code (caustic_web / creature_light). Registered here, not in
## project.godot: that file is part of the native layer and cannot reach installed APKs by OTA.
## Settings is the first OTA-delivered autoload, so this runs before any scene compiles a shader.
func _init() -> void:
	var g := {
		"mote_clarity": [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
		"mote_lamp_dir": [RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3(0.29, 0.95, -0.1)],
		"mote_caustic_tex": [RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D,
			load("res://assets/textures/noise_rgb.png")],
	}
	for n in g:
		RenderingServer.global_shader_parameter_add(n, g[n][0], g[n][1])


func _enter_tree() -> void:
	StartupTrace.mark("autoload Settings")
	_setup_input_map()
	_load()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--test="):
			test_mode = a.substr(7)
		elif a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			test_args[kv[0]] = kv[1]
	# (After the command line: automated runs are always the main player.)
	if Players.current() != Players.MAIN:
		load_player_look()
	_apply_audio()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_pad_connected = Input.get_connected_joypads().size() > 0


func _setup_input_map() -> void:
	var defs := {
		"move_left": [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)],
		"move_right": [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)],
		"move_forward": [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)],
		"move_back": [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)],
		"cam_left": [_key(KEY_Q), _axis(JOY_AXIS_RIGHT_X, -1.0)],
		"cam_right": [_key(KEY_E), _axis(JOY_AXIS_RIGHT_X, 1.0)],
		"cam_up": [_key(KEY_R), _axis(JOY_AXIS_RIGHT_Y, -1.0)],
		"cam_down": [_key(KEY_F), _axis(JOY_AXIS_RIGHT_Y, 1.0)],
		"jump": [_key(KEY_SPACE), _btn(JOY_BUTTON_A)],
		"swipe": [_key(KEY_J), _btn(JOY_BUTTON_X)],
		"lunge": [_key(KEY_K), _btn(JOY_BUTTON_B)],
		"special": [_key(KEY_L), _btn(JOY_BUTTON_Y)],
		"pause": [_key(KEY_ESCAPE), _key(KEY_P), _btn(JOY_BUTTON_START)],
		# The whole-ball view (ledger row 21; BallView): the pad's Back / View / Select button.
		"view_ball": [_key(KEY_V), _btn(JOY_BUTTON_BACK)],
	}
	for action in defs:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for ev in defs[action]:
			InputMap.action_add_event(action, ev)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _btn(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.device = -1
	return e


func _axis(ax: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = ax
	e.axis_value = v
	e.device = -1
	return e


func _input(event: InputEvent) -> void:
	# Automatic touch <-> controller switching.
	if event is InputEventJoypadButton and event.pressed:
		_set_mode(InputMode.PAD)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		_set_mode(InputMode.PAD)
	elif event is InputEventScreenTouch and event.pressed:
		_set_mode(InputMode.TOUCH)


func _set_mode(m: int) -> void:
	if m != input_mode:
		input_mode = m
		input_mode_changed.emit(m)


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	_pad_connected = Input.get_connected_joypads().size() > 0
	if not connected and not _pad_connected:
		_set_mode(InputMode.TOUCH)
	settings_changed.emit()


func controller_status() -> String:
	var parts := []
	parts.append("Controller: " + ("connected" if _pad_connected else "none"))
	parts.append("Active: " + ("controller" if input_mode == InputMode.PAD else "touch"))
	if _pad_connected:
		parts.append("Back: whole-ball view")
	return "   ".join(parts)


# --- Haptics -------------------------------------------------------------------------

## kind: "tap" (swipe connects), "mote", "land", "heavy", "vortex", "hurt"
func haptic(kind: String) -> void:
	if not haptics:
		return
	var ms := 20
	var amp := 0.3
	match kind:
		"tap": ms = 15; amp = 0.25
		"mote": ms = 25; amp = 0.3
		"land": ms = 45; amp = 0.55
		"heavy": ms = 80; amp = 0.8
		"hurt": ms = 40; amp = 0.5
		"vortex": ms = 140; amp = 0.4
	if input_mode == InputMode.PAD and _pad_connected:
		Input.start_joy_vibration(Input.get_connected_joypads()[0], amp, amp * 0.6, ms / 1000.0)
	elif OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, amp)


# --- Persistence ---------------------------------------------------------------------

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	reduced_hud = cf.get_value("hud", "reduced", reduced_hud)
	show_run_timer = cf.get_value("hud", "run_timer", show_run_timer)
	haptics = cf.get_value("hud", "haptics", haptics)
	swim_invert_y = bool(cf.get_value("controls", "swim_invert_y", swim_invert_y))
	tutorials = bool(cf.get_value("onboarding", "tutorials", tutorials))
	music_volume = cf.get_value("audio", "music", music_volume)
	sfx_volume = cf.get_value("audio", "sfx", sfx_volume)
	# (Added after dev-000024; absent in older files, which keep the original pink.)
	gill_morph = str(cf.get_value("gill", "morph", gill_morph))
	gill_body_hue = float(cf.get_value("gill", "body_hue", gill_body_hue))
	gill_body_bright = float(cf.get_value("gill", "body_bright", gill_body_bright))
	gill_dots_hue = float(cf.get_value("gill", "dots_hue", gill_dots_hue))
	gill_dots_bright = float(cf.get_value("gill", "dots_bright", gill_dots_bright))
	gill_pattern = str(cf.get_value("gill", "pattern", gill_pattern))
	gill_pattern_mode = int(cf.get_value("gill", "pattern_mode", gill_pattern_mode))
	gill_pattern_size = int(cf.get_value("gill", "pattern_size", gill_pattern_size))
	gill_pattern_alpha = bool(cf.get_value("gill", "pattern_alpha", gill_pattern_alpha))


## Sets his colours, saves them and tells every model.
func set_gill_look(morph_id: String, body_hue: float, body_bright: float, dots_hue: float, dots_bright: float) -> void:
	gill_morph = morph_id
	gill_body_hue = body_hue
	gill_body_bright = body_bright
	gill_dots_hue = dots_hue
	gill_dots_bright = dots_bright
	save()
	gill_look_changed.emit()


## Sets his pattern (GillLook), saves it and tells every model.
func set_gill_pattern(id: String, mode: int, size: int) -> void:
	gill_pattern = id
	gill_pattern_mode = mode
	gill_pattern_size = size
	save()
	gill_look_changed.emit()


## The colour fields (one player's look). The main player's live in settings.cfg's "gill" section;
## any other player's in their own look.cfg (Players), same section and keys.
const LOOK_KEYS := {"morph": "gill_morph", "body_hue": "gill_body_hue", "body_bright": "gill_body_bright",
		"dots_hue": "gill_dots_hue", "dots_bright": "gill_dots_bright", "pattern": "gill_pattern",
		"pattern_mode": "gill_pattern_mode", "pattern_size": "gill_pattern_size", "pattern_alpha": "gill_pattern_alpha"}
## The main player's look as read from settings.cfg, while another player is playing (written back
## there unchanged on every save, so the main player's colours are never touched).
var _main_look := {}


func _look() -> Dictionary:
	var d := {}
	for k in LOOK_KEYS:
		d[k] = get(LOOK_KEYS[k])
	return d


func _set_look(d: Dictionary) -> void:
	for k in LOOK_KEYS:
		if d.has(k):
			set(LOOK_KEYS[k], type_convert(d[k], typeof(get(LOOK_KEYS[k]))))


## Puts on the current player's colours (at launch, and when the player changes). A new player
## starts with the default look.
func load_player_look() -> void:
	if not _main_look.is_empty():
		_set_look(_main_look)
		_main_look = {}
	var path := Players.look_path()
	if path == "":
		gill_look_changed.emit()
		return
	_main_look = _look()
	var defaults := {"morph": "pink", "body_hue": 0.0, "body_bright": 1.0, "dots_hue": 0.0, "dots_bright": 1.0,
			"pattern": "none", "pattern_mode": 0, "pattern_size": 3, "pattern_alpha": false}
	_set_look(defaults)
	var cf := ConfigFile.new()
	if cf.load(path) == OK:
		var d := {}
		for k in LOOK_KEYS:
			d[k] = cf.get_value("gill", k, defaults[k])
		_set_look(d)
	gill_look_changed.emit()


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("hud", "reduced", reduced_hud)
	cf.set_value("hud", "run_timer", show_run_timer)
	cf.set_value("hud", "haptics", haptics)
	cf.set_value("controls", "swim_invert_y", swim_invert_y)
	cf.set_value("onboarding", "tutorials", tutorials)
	cf.set_value("audio", "music", music_volume)
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("gill", "morph", gill_morph)
	cf.set_value("gill", "body_hue", gill_body_hue)
	cf.set_value("gill", "body_bright", gill_body_bright)
	cf.set_value("gill", "dots_hue", gill_dots_hue)
	cf.set_value("gill", "dots_bright", gill_dots_bright)
	cf.set_value("gill", "pattern", gill_pattern)
	cf.set_value("gill", "pattern_mode", gill_pattern_mode)
	cf.set_value("gill", "pattern_size", gill_pattern_size)
	cf.set_value("gill", "pattern_alpha", gill_pattern_alpha)
	for k in save_meta():
		cf.set_value("meta", k, save_meta()[k])
	if not _main_look.is_empty():
		# Another player is playing: settings.cfg keeps the main player's colours, theirs go to
		# their own file.
		var mine := ConfigFile.new()
		for k in LOOK_KEYS:
			mine.set_value("gill", k, get(LOOK_KEYS[k]))
			cf.set_value("gill", k, _main_look[k])
		var lp := Players.look_path()
		if lp != "":
			DirAccess.make_dir_recursive_absolute(lp.get_base_dir())
			mine.save(lp)
	cf.save(SETTINGS_PATH)
	_apply_audio()
	settings_changed.emit()


## Identity written alongside persisted data. Compatibility decisions use save_schema only;
## the rest is there to reconstruct which build wrote the file.
func save_meta() -> Dictionary:
	var id: Dictionary = Boot.identity()
	return {"save_schema": SaveSchema.SAVE_SCHEMA, "game_version": GameVersion.GAME_VERSION,
			"native_build": id["native_build"], "build_flavor": id["build_flavor"],
			"ota_id": id["ota_id"], "source_sha": id["source_sha"]}


func _apply_audio() -> void:
	# Ambience and Outside buses route into SFX, so the SFX slider scales them too; their own
	# levels are driven by the AudioDirector.
	var m := AudioServer.get_bus_index("Music")
	if m >= 0:
		AudioServer.set_bus_volume_db(m, linear_to_db(maxf(music_volume, 0.0001)))
	var s := AudioServer.get_bus_index("SFX")
	if s >= 0:
		AudioServer.set_bus_volume_db(s, linear_to_db(maxf(sfx_volume, 0.0001)))


func apply_audio() -> void:
	_apply_audio()
