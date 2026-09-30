class_name OrganicMotion
extends RefCounted
## The expression layer of enemy movement (Open Issue #3, organic enemy movement): deterministic
## underneath, apparently spontaneous to the observer.
##
## A creature's AI stays its INTENT (graze, prowl, pursue, retreat, guard, return home...). This adds
## EXPRESSION on top: a slow directional drift and a medium weave bent into the direction it wants
## to go, gentle speed changes with rare hesitations, a heavier or lighter turning momentum, a
## vertical wander for swimmers, and small visual corrections (head look, nod) that never move a
## gameplay collider. The creature's own move and collision step still decides where it can go:
## this only bends the input to that step.
##
## Each output is 2-3 sines at non-harmonic frequency ratios (golden, silver, plastic), with phases
## and a personal tempo hashed from the creature's own seed, and a very slow amplitude modulation,
## so no two individuals move in step and no creature repeats itself over minutes. Hesitations
## come from a thresholded slow signal: rare, brief, never on a timer. Everything is an absolute
## function of the creature's accumulated simulated time (frame-rate independent); weights ease
## exponentially. No random draws, ever: the gameplay random sequence and the creatures' own
## generators are untouched.
##
## Weights: the caller says how much expression each state allows (path, speed, look). Committed
## attacks (wind-ups, lunges, charges, pounces, strikes) cut path and speed to zero at once, so the
## committed geometry is exactly what it was without the layer.

## Global switch (on/off comparisons and tests). Off, every output is neutral.
static var enabled := true

const R_GOLD := 1.6180339887
const R_SILVER := 2.4142135624
const R_PLASTIC := 1.3247179572
## Weights ease toward their targets at this rate (1/s).
const EASE := 3.0
## A committed state fades the (visual only) look this fast.
const LOOK_CUT := 12.0

# --- Profiles (per species personality) ----------------------------------------------------
# drift: slow directional drift [rad, Hz]; weave: medium weave [rad, Hz]; speed: [fraction, Hz];
# hes: hesitation [Hz, threshold (-1..1), depth]; lift: vertical wander [m, Hz]; look: head/body
# look [rad, Hz]; turn: turning-rate factor at full weight (lower = heavier momentum); warp: how
# far its tempo wanders [fraction, Hz of the wandering] (default 20% over about a minute).

## Small parasite: nervous. Quick, small corrections; frequent little hesitations; darting look.
const PARASITE_SMALL := {"drift": Vector2(0.38, 0.07), "weave": Vector2(0.2, 0.42), "speed": Vector2(0.24, 0.31),
		"hes": Vector3(0.11, 0.7, 0.85), "look": Vector2(0.3, 0.55), "turn": 0.6}
## Medium parasite: a steady crawler that wanders in loose arcs and stops now and then to look.
const PARASITE_MEDIUM := {"drift": Vector2(0.5, 0.045), "weave": Vector2(0.13, 0.26), "speed": Vector2(0.18, 0.16),
		"hes": Vector3(0.06, 0.76, 0.8), "look": Vector2(0.22, 0.33), "turn": 0.5}
## Large parasite: heavy. Broad slow arcs, a lot of momentum, rare pauses.
const PARASITE_LARGE := {"drift": Vector2(0.58, 0.027), "weave": Vector2(0.07, 0.15), "speed": Vector2(0.14, 0.085),
		"hes": Vector3(0.035, 0.8, 0.7), "look": Vector2(0.14, 0.19), "turn": 0.32}
## Spitter: a medium that watches more than it wanders.
const PARASITE_SPITTER := {"drift": Vector2(0.42, 0.05), "weave": Vector2(0.12, 0.3), "speed": Vector2(0.2, 0.18),
		"hes": Vector3(0.07, 0.72, 0.8), "look": Vector2(0.3, 0.28), "turn": 0.55}
## Reed stalker: slinks. Long curving prowls, stop-and-go pauses, a head that bobs and scans.
const STALKER := {"drift": Vector2(0.45, 0.03), "weave": Vector2(0.1, 0.19), "speed": Vector2(0.3, 0.075),
		"hes": Vector3(0.05, 0.66, 0.9), "lift": Vector2(0.035, 0.45), "look": Vector2(0.2, 0.22), "turn": 0.5}
## Pufferfish: floats. A bounded lateral drift (metres), a slow rise and sink, a lazy roll.
const PUFFER := {"wander": true, "drift": Vector2(0.9, 0.028), "weave": Vector2(0.22, 0.1), "lift": Vector2(0.22, 0.045),
		"look": Vector2(0.07, 0.12)}
## Crab: guards. Small sidesteps at its post (metres), a slow body turn, arcs walking home.
const CRAB := {"drift": Vector2(0.3, 0.09), "weave": Vector2(0.08, 0.3), "speed": Vector2(0.15, 0.2),
		"hes": Vector3(0.05, 0.7, 0.0), "lift": Vector2(0.22, 0.04), "look": Vector2(0.13, 0.08), "turn": 1.0,
		"warp": Vector2(0.25, 0.009)}
## Cave eel: a flowing head sway in its crevice, and now and then a slight peek out.
const EEL := {"lift": Vector2(0.04, 0.05), "look": Vector2(0.2, 0.07), "hes": Vector3(0.04, 0.7, 0.0), "warp": Vector2(0.25, 0.009)}

# --- Outputs (read after step) -------------------------------------------------------------

## Heading offset for the path (radians, weighted).
var yaw := 0.0
## Speed multiplier (weighted; includes hesitations).
var speed := 1.0
## Turning-rate multiplier (weighted momentum).
var turn := 1.0
## Vertical (or, for walkers, the profile's own) offset in metres (weighted by path).
var lift := 0.0
## Visual head/body look yaw and nod (radians, weighted by look).
var look := 0.0
var nod := 0.0
## Hesitation gate 0..1 (unweighted).
var hes := 0.0
## Current weights.
var w_path := 0.0
var w_speed := 0.0
var w_look := 0.0

var _t := 0.0
var _ph := PackedFloat64Array()
var _tempo := 1.0
var _tempo2 := 1.0
# Amplitudes and angular frequencies of the current profile.
var _da := 0.0
var _dw := 0.0
var _wa := 0.0
var _ww := 0.0
var _sa := 0.0
var _sw := 0.0
var _hw := 0.0
var _hth := 2.0
var _hdep := 0.0
var _la := 0.0
var _lw := 0.0
var _ka := 0.0
var _kw := 0.0
var _turn := 1.0
## Steers by wander2() only (no heading offset to compute).
var _wander_only := false
var _mw := 0.0
# The individual's own time warp (its tempo wanders): angular frequency and depth (seconds).
var _xw := 0.0
var _xd := 0.0
## Warped time and its rate of change (this step).
var _tau := 0.0
var _taud := 1.0


## `seed_v`: the creature's own stable seed (read, never drawn from).
func _init(seed_v: int, profile: Dictionary = {}) -> void:
	_ph.resize(20)
	for k in 20:
		_ph[k] = unit(seed_v, k) * TAU
	# Its own tempo: same-species individuals never share frequencies exactly.
	_tempo = 0.8 + 0.45 * unit(seed_v, 20)
	_tempo2 = 0.8 + 0.45 * unit(seed_v, 21)
	# Its own place in time.
	_t = unit(seed_v, 22) * 600.0
	set_profile(profile)


## A stable 0..1 value from a seed and a channel (no generator involved).
static func unit(seed_v: int, k: int) -> float:
	return float(hash([seed_v, k, 7270]) & 0xFFFFFF) / 16777216.0


func set_profile(p: Dictionary) -> void:
	var v: Vector2 = p.get("drift", Vector2.ZERO)
	_da = v.x
	_dw = TAU * v.y * _tempo
	v = p.get("weave", Vector2.ZERO)
	_wa = v.x
	_ww = TAU * v.y * _tempo2
	v = p.get("speed", Vector2.ZERO)
	_sa = v.x
	_sw = TAU * v.y * _tempo2
	var h: Vector3 = p.get("hes", Vector3(0.0, 2.0, 0.0))
	_hw = TAU * h.x * _tempo
	_hth = h.y
	_hdep = h.z
	v = p.get("lift", Vector2.ZERO)
	_la = v.x
	_lw = TAU * v.y * _tempo
	v = p.get("look", Vector2.ZERO)
	_ka = v.x
	_kw = TAU * v.y * _tempo2
	_turn = float(p.get("turn", 1.0))
	_wander_only = bool(p.get("wander", false))
	_mw = TAU * 0.013 * _tempo2
	# (Its tempo wanders by `x` (a fraction) over minutes: fast rhythms never lock into a loop.)
	v = p.get("warp", Vector2(0.2, 0.017))
	_xw = TAU * v.y * _tempo
	_xd = v.x / (_xw * (0.6 + 0.4 * R_PLASTIC))


## Advances the clock by `dt` and computes the outputs. `wp`, `ws`, `wl`: the weights this state
## allows for path, speed and look (0..1). `cut`: a committed state (path and speed to 0 at once).
## `pause`: hesitations may slow it (not while it hunts: spotting prey ends a pause).
func step(dt: float, wp: float, ws: float, wl: float, cut := false, pause := true) -> void:
	_t += dt
	var k := 1.0 - exp(-dt * EASE)
	if cut:
		w_path = 0.0
		w_speed = 0.0
		w_look += (0.0 - w_look) * (1.0 - exp(-dt * LOOK_CUT))
	else:
		w_path += (wp - w_path) * k
		w_speed += (ws - w_speed) * k
		w_look += (wl - w_look) * k
	if not enabled:
		yaw = 0.0
		speed = 1.0
		turn = 1.0
		lift = 0.0
		look = 0.0
		nod = 0.0
		hes = 0.0
		return
	var t := _t
	var ph := _ph
	# Its own warped time (every rhythm below runs on it).
	var x1 := _xw * t + ph[15]
	var x2 := _xw * R_PLASTIC * t + ph[16]
	_tau = t + _xd * (0.6 * sin(x1) + 0.4 * sin(x2))
	_taud = 1.0 + _xd * _xw * (0.6 * cos(x1) + 0.4 * R_PLASTIC * cos(x2))
	var u := _tau
	# Hesitation: two slow sines at a silver ratio rarely line up above the threshold.
	hes = 0.0
	if _hw > 0.0:
		var h := 0.5 * (sin(_hw * t + ph[4]) + sin(_hw * R_SILVER * t + ph[5]))
		if h > _hth:
			hes = smoothstep(_hth, _hth + 0.12, h)
	# Path: slow drift (three sines; its amplitude itself breathing very slowly) plus a weave.
	yaw = 0.0
	if w_path > 0.0005 and not _wander_only:
		var m := 0.7 + 0.3 * sin(_mw * t + ph[6])
		yaw = w_path * (_da * m * (0.45 * sin(_dw * u + ph[0]) + 0.33 * sin(_dw * R_GOLD * u + ph[1]) + 0.22 * sin(_dw * R_SILVER * u + ph[14]))
				+ _wa * (0.6 * sin(_ww * u + ph[2]) + 0.4 * sin(_ww * R_SILVER * u + ph[3])))
	turn = lerpf(1.0, _turn, w_path)
	speed = 1.0
	if w_speed > 0.0005:
		speed = 1.0 + w_speed * (_sa * (0.6 * sin(_sw * u + ph[7]) + 0.4 * sin(_sw * R_PLASTIC * u + ph[8])) - (_hdep * hes if pause else 0.0))
	lift = 0.0
	if _la > 0.0:
		lift = w_path * _la * (0.6 * sin(_lw * u + ph[9]) + 0.4 * sin(_lw * R_GOLD * u + ph[10]))
	look = 0.0
	nod = 0.0
	if w_look > 0.0005 and _ka > 0.0:
		# (It looks round more while it pauses.)
		var a := w_look * _ka * (1.0 + 1.2 * hes)
		look = a * (0.45 * sin(_kw * u + ph[11]) + 0.3 * sin(_kw / R_GOLD * u + ph[12]) + 0.25 * sin(_kw * R_SILVER * u + ph[17]))
		nod = a * 0.5 * sin(_kw * R_PLASTIC * u + ph[13])


## A bounded drift of the path, in metres (x, y) and its rate of change (z, w): for creatures that
## steer by velocity (the pufferfish). Weighted by path. Uses the drift and weave channels.
func wander2() -> Vector4:
	if not enabled or w_path <= 0.0005:
		return Vector4.ZERO
	var t := _tau
	var ph := _ph
	var a := _dw
	var b := _dw * R_GOLD
	var c := _dw * R_PLASTIC
	var d := _dw * R_SILVER
	var e := _ww
	var f := _ww * R_GOLD
	var x := _da * (0.65 * sin(a * t + ph[0]) + 0.35 * sin(b * t + ph[1])) + _wa * sin(e * t + ph[2])
	var y := _da * (0.65 * sin(c * t + ph[3]) + 0.35 * sin(d * t + ph[7])) + _wa * sin(f * t + ph[8])
	var dx := _da * (0.65 * a * cos(a * t + ph[0]) + 0.35 * b * cos(b * t + ph[1])) + _wa * e * cos(e * t + ph[2])
	var dy := _da * (0.65 * c * cos(c * t + ph[3]) + 0.35 * d * cos(d * t + ph[7])) + _wa * f * cos(f * t + ph[8])
	return Vector4(x, y, dx * _taud, dy * _taud) * w_path


## A rhythm's phase (cycles) whose tempo drifts gently: `rate` cycles per second on average,
## never stopping or running backwards (the small parasite's darting).
func warp(clock: float, rate: float) -> float:
	if not enabled:
		return clock * rate
	var w := rate * 0.49
	return clock * rate + 0.25 * sin(w * clock + _ph[9]) + 0.12 * sin(w * R_GOLD * clock + _ph[10])


## Weights back to zero (a creature set down somewhere new).
func reset_weights() -> void:
	w_path = 0.0
	w_speed = 0.0
	w_look = 0.0


func snapshot() -> Array:
	return [_t, w_path, w_speed, w_look]


func restore(s: Array) -> void:
	_t = s[0]
	w_path = s[1]
	w_speed = s[2]
	w_look = s[3]
