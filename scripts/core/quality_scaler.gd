class_name QualityScaler
extends Node
## Quiet thermal/performance scaling. Targets 60 FPS; when sustained frame rate drops, it
## steps down secondary visual cost only (the ceiling light's shadows first, then resolution
## scale, particles, glow, secondary lights). Controls, camera, character and restoration readability are
## never touched, and neither is the vegetation: thinning it hid a share of the plants right round
## Gill at every step down, which read as plants popping out (owner, 2026-10-07). Recovers slowly with hysteresis. No messages are ever shown.

var level := 0
var mote_lights := 3
var _acc := 0.0
var _frames := 0
var _low_windows := 0
var _high_windows := 0
var _cooldown := 0.0
var history: Array = []

## "shadow": the ceiling light's shadow distance in metres (0 = none; Expansion 6).
const LEVELS := [
	{"scale": 1.0, "specks": 420, "glow": true, "lights": 3, "shadow": 30.0},
	# (Shadows go first: they are most of what the Expansion 6 lighting costs.)
	{"scale": 0.9, "specks": 300, "glow": true, "lights": 2, "shadow": 0.0},
	{"scale": 0.8, "specks": 200, "glow": false, "lights": 1, "shadow": 0.0},
	{"scale": 0.7, "specks": 120, "glow": false, "lights": 1, "shadow": 0.0},
]


func _ready() -> void:
	# Mobile screens are dense; start slightly below native resolution for the 3D pass.
	if OS.has_feature("mobile"):
		get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	_apply()


func _process(dt: float) -> void:
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
		return
	_acc += dt
	_frames += 1
	_cooldown = maxf(0.0, _cooldown - dt)
	if _acc < 2.0:
		return
	var fps := _frames / _acc
	history.append(fps)
	if history.size() > 120:
		history.pop_front()
	_acc = 0.0
	_frames = 0
	if fps < 54.0:
		_low_windows += 1
		_high_windows = 0
	elif fps > 59.0:
		_high_windows += 1
		_low_windows = 0
	else:
		_low_windows = 0
		_high_windows = 0
	if _low_windows >= 2 and level < LEVELS.size() - 1 and _cooldown <= 0.0:
		level += 1
		_low_windows = 0
		_cooldown = 6.0
		_apply()
	elif _high_windows >= 15 and level > 0 and _cooldown <= 0.0:
		level -= 1
		_high_windows = 0
		_cooldown = 20.0
		_apply()


func force_level(l: int) -> void:
	level = clampi(l, 0, LEVELS.size() - 1)
	_apply()


func _apply() -> void:
	var q: Dictionary = LEVELS[level]
	get_viewport().scaling_3d_scale = q["scale"] * (0.85 if OS.has_feature("mobile") else 1.0)
	if WaterFX.inst:
		WaterFX.inst.set_speck_density(q["specks"])
	var g := Game.inst
	if g:
		if g.aquarium and g.aquarium.sun:
			g.aquarium.sun.shadow_enabled = q["shadow"] > 0.0
			g.aquarium.sun.directional_shadow_max_distance = maxf(q["shadow"], 1.0)
		if g.env:
			g.env.glow_enabled = q["glow"]
	mote_lights = q["lights"]
