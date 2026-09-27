class_name Sfx
extends Node
## Pooled one-shot sound effects. Streams are loaded lazily from res://assets/audio/sfx_<name>.wav.

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


## Plays a sound at a world position (or non-positional when pos is null).
static func play(sfx_name: String, pos: Variant = null, vol_db := 0.0, pitch_var := 0.08) -> void:
	if inst == null:
		return
	var s := inst.stream(sfx_name)
	if s == null:
		return
	if pos == null:
		var p := inst._players2d[inst._n2]
		inst._n2 = (inst._n2 + 1) % inst._players2d.size()
		p.stream = s
		p.volume_db = vol_db
		p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
		p.play()
	else:
		var p := inst._players3d[inst._n3]
		inst._n3 = (inst._n3 + 1) % inst._players3d.size()
		p.stream = s
		p.global_position = pos
		p.volume_db = vol_db
		p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
		p.play()
