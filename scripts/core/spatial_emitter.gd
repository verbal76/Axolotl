class_name SpatialEmitter
extends Node3D
## A positional sound (2026-10-13): the game's replacement for AudioStreamPlayer3D, with the same
## properties and the engine's own 3D model, played through a SpatialAudio voice so that the engine
## never replaces a playing sound's routing data (ledger row 37; see SpatialAudio).
## `volume_db`, `unit_size`, `max_distance` and the filter may change at any time, even while it
## plays: they only feed the next frame's voice-bus values.

@export var stream: AudioStream
## The destination bus (SFX or Ambience).
@export var bus: StringName = &"SFX"
@export var volume_db := 0.0
@export var unit_size := 10.0
@export var max_db := 3.0
@export var max_distance := 0.0
@export var attenuation_filter_cutoff_hz := 5000.0
@export var attenuation_filter_db := -24.0
@export var panning_strength := 1.0
@export var autoplay := false
## Pitch: applied when it starts; while playing it is passed on (an atomic value in the engine).
var pitch_scale := 1.0:
	set(v):
		pitch_scale = v
		if _voice != null:
			_voice.player.pitch_scale = v
var playing: bool:
	get:
		return _voice != null and _voice.player.playing
## The distance high-shelf gain of the last update (SpatialAudio.gains).
var shelf_gain := 1.0
var _voice = null   # SpatialAudio.Voice


func _ready() -> void:
	if autoplay:
		play.call_deferred()


func _exit_tree() -> void:
	stop()


func looping() -> bool:
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	if stream is AudioStreamOggVorbis:
		return (stream as AudioStreamOggVorbis).loop
	return false


func play(from_position := 0.0) -> void:
	stop()
	var sa := SpatialAudio.inst
	if stream == null or not is_inside_tree() or sa == null or not is_instance_valid(sa) or not sa.is_inside_tree():
		return
	var v = sa.acquire(self)
	if v == null:
		return
	_voice = v
	# (The voice's player is stopped here: its stream and pitch are set before it plays, never while.)
	v.player.stream = stream
	v.player.pitch_scale = pitch_scale
	sa.apply(v, self)
	v.player.play(from_position)


func stop() -> void:
	if _voice == null:
		return
	var v = _voice
	_voice = null
	var sa := SpatialAudio.inst
	if sa != null and is_instance_valid(sa) and v.emitter == self:
		sa.release(v)


## Its voice was taken for a newer sound (all voices busy).
func _lost_voice() -> void:
	_voice = null
