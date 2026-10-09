class_name Sfx
extends Node
## Pooled one-shot sound effects. Streams are loaded lazily from res://assets/audio/sfx_<name>.wav.

## Cosmetic randomness (Expansion 6): its own generator, never the gameplay random sequence
## that deterministic playthroughs and tests rely on.
static var _fx_rng := RandomNumberGenerator.new()

static var inst: Sfx

var _streams := {}
var _players3d: Array[AudioStreamPlayer3D] = []
var _players2d: Array[AudioStreamPlayer] = []
var _n3 := 0
var _n2 := 0


func _init() -> void:
	inst = self


func _ready() -> void:
	for i in 14:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 6.0
		p.max_distance = 60.0
		p.attenuation_filter_cutoff_hz = 9000.0
		add_child(p)
		_players3d.append(p)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players2d.append(p)


func stream(sfx_name: String) -> AudioStream:
	if not _streams.has(sfx_name):
		var path := "res://assets/audio/sfx_%s.wav" % sfx_name
		_streams[sfx_name] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sfx_name]


## Same-moment clarity (v107, owner 2026-10-08; the audit found one deflection playing swipe_hit
## twice and a parasite kill stacking up to ~7 sounds in one frame): a sound already started this
## frame is not started again, and a subordinate sound gives way to the one that says the same
## thing louder (the generic parasite "hit" under a tail swipe's "swipe_hit"). Sounds never drive
## gameplay; this only decides which of a frame's duplicates is heard.
const SUBORDINATE := {"hit": "swipe_hit"}
var _frame := -1
var _frame_played := {}
## Sounds skipped as same-frame duplicates or subordinates (tests and diagnostics).
static var skipped := 0


## Plays a sound at a world position (or non-positional when pos is null). `pitch` sets its base
## pitch (a lighter or heavier version of the same sound); `pitch_var` varies it a little each time.
static func play(sfx_name: String, pos: Variant = null, vol_db := 0.0, pitch_var := 0.08, pitch := 1.0) -> void:
	if inst == null:
		return
	var s := inst.stream(sfx_name)
	if s == null:
		return
	var f := Engine.get_process_frames()
	if f != inst._frame:
		inst._frame = f
		inst._frame_played.clear()
	if inst._frame_played.has(sfx_name) or inst._frame_played.has(SUBORDINATE.get(sfx_name, "")):
		skipped += 1
		return
	for sub in SUBORDINATE:
		if SUBORDINATE[sub] == sfx_name and inst._frame_played.has(sub):
			var under = inst._frame_played[sub]
			if is_instance_valid(under):
				under.stop()
	var player: Node
	if pos == null:
		var p := inst._players2d[inst._n2]
		inst._n2 = (inst._n2 + 1) % inst._players2d.size()
		p.stream = s
		p.volume_db = vol_db
		p.pitch_scale = pitch * (1.0 + _fx_rng.randf_range(-pitch_var, pitch_var))
		p.play()
		player = p
	else:
		var p := inst._players3d[inst._n3]
		inst._n3 = (inst._n3 + 1) % inst._players3d.size()
		p.stream = s
		p.global_position = pos
		p.volume_db = vol_db
		p.pitch_scale = pitch * (1.0 + _fx_rng.randf_range(-pitch_var, pitch_var))
		p.play()
		player = p
	inst._frame_played[sfx_name] = player
