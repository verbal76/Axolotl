class_name SpatialAudio
extends Node
## Positional sound without AudioStreamPlayer3D (2026-10-13, ledger row 37: the audio-thread crash).
##
## Godot 4.7.2 frees a playback's routing data ("bus details") on the main thread two frames after
## replacing it, with no synchronisation with the audio thread that may still be reading it
## (servers/audio/audio_server.cpp: set_playback_bus_volumes_linear -> bus_details_graveyard ->
## _cleanup_lists). The replacement happens only when a playing player's volume or bus is written, and
## on every physics tick for every playing AudioStreamPlayer3D within earshot. The game therefore never
## lets the engine replace routing data while a sound plays:
##   - no AudioStreamPlayer3D: each positional sound (SpatialEmitter) plays through a plain
##     AudioStreamPlayer on a voice bus of its own, whose player volume is never written while playing;
##   - the engine's own 3D model (inverse-distance attenuation, max_db, the max_distance fade, stereo
##     panning at the project's panning strength, the distance high-shelf filter) is applied every frame
##     to that voice bus: its volume, an AudioEffectPanner and an AudioEffectHighShelfFilter, which are
##     plain values the audio thread reads (nothing is allocated or freed);
##   - buses are created once, under the audio driver's lock (AudioServer.add_bus is not synchronised
##     with the mix either), and a voice bus's send never changes afterwards.
## Sounds are mono, so the panner reproduces the engine's left/right gains exactly. One difference:
## the engine ramps a 3D player's gain within each mix block, a bus volume steps between blocks (at
## this game's speeds, under 0.2 dB per frame).

static var inst: SpatialAudio

## Voices per destination bus (the bus the emitter names, e.g. SFX or Ambience).
const VOICES := {"SFX": 20, "Ambience": 12}
const DEFAULT_VOICES := 4
const SILENT_DB := -80.0
const CMP_EPSILON := 0.00001

var _groups := {}   # destination bus -> Array[Voice]
var _panning := 0.5


class Voice:
	var player: AudioStreamPlayer
	var bus_name: StringName
	var bus_idx := -1
	var panner: AudioEffectPanner
	var shelf: AudioEffectHighShelfFilter
	var emitter: SpatialEmitter
	var started_ms := 0


func _init() -> void:
	inst = self
	process_priority = 1000


func _enter_tree() -> void:
	_panning = float(ProjectSettings.get_setting("audio/general/3d_panning_strength", 0.5))
	for dest in VOICES:
		_ensure_group(dest)


func _exit_tree() -> void:
	if inst == self:
		inst = null


## The voice buses for one destination: made once (or found again after a scene reload).
func _ensure_group(dest: StringName) -> Array:
	if _groups.has(dest):
		return _groups[dest]
	# (A bus sends only to a bus before it: the destination must exist first, or the voices would
	# skip its volume and go straight to Master.)
	var dest_idx := AudioServer.get_bus_index(dest)
	if dest_idx < 0:
		return []
	var n: int = VOICES.get(dest, DEFAULT_VOICES)
	var voices: Array = []
	# (Bus layout changes are not synchronised with the mix in 4.7.2: made with the driver locked.)
	AudioServer.lock()
	for i in n:
		var name := "Voice.%s.%d" % [dest, i]
		var idx := AudioServer.get_bus_index(name)
		if idx >= 0 and idx < dest_idx:
			push_warning("SpatialAudio: %s precedes %s" % [name, dest])
		if idx < 0:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, name)
			AudioServer.set_bus_send(idx, dest)
			AudioServer.set_bus_volume_db(idx, SILENT_DB)
			var pan := AudioEffectPanner.new()
			AudioServer.add_bus_effect(idx, pan)
			var shelf := AudioEffectHighShelfFilter.new()
			shelf.resonance = 1.0
			shelf.db = AudioEffectFilter.FILTER_6DB
			AudioServer.add_bus_effect(idx, shelf)
		var v := Voice.new()
		v.bus_name = name
		v.bus_idx = idx
		v.panner = AudioServer.get_bus_effect(idx, 0)
		v.shelf = AudioServer.get_bus_effect(idx, 1)
		v.player = AudioStreamPlayer.new()
		v.player.name = name
		v.player.bus = name
		add_child(v.player)
		voices.append(v)
	AudioServer.unlock()
	_groups[dest] = voices
	return voices


## A free voice for this emitter (or the oldest one-shot's, which is stopped first), null if none.
func acquire(e: SpatialEmitter) -> Voice:
	var voices := _ensure_group(e.bus)
	var free: Voice = null
	var oldest: Voice = null
	for v in voices:
		if v.emitter == null or not is_instance_valid(v.emitter):
			v.emitter = null
			free = v
			break
		if not v.emitter.looping() and (oldest == null or v.started_ms < oldest.started_ms):
			oldest = v
	if free == null and oldest != null:
		oldest.emitter._lost_voice()
		free = oldest
	if free == null:
		return null
	free.player.stop()
	free.emitter = e
	free.started_ms = Time.get_ticks_msec()
	return free


func release(v: Voice) -> void:
	if v == null:
		return
	v.player.stop()
	AudioServer.set_bus_volume_db(v.bus_idx, SILENT_DB)
	v.emitter = null


## The engine's 3D model for one emitter, applied to its voice bus. Returns [left, right] gains.
func apply(v: Voice, e: SpatialEmitter) -> Vector2:
	var lr := gains(e)
	var sum := lr.x + lr.y
	var g := sum * 0.5
	AudioServer.set_bus_volume_db(v.bus_idx, linear_to_db(g) if g > 0.0 else SILENT_DB)
	v.panner.pan = (lr.y - lr.x) / sum if sum > 0.0 else 0.0
	v.shelf.cutoff_hz = e.attenuation_filter_cutoff_hz
	v.shelf.gain = e.shelf_gain
	return lr


## AudioStreamPlayer3D._update_panning (Godot 4.7.2, stereo, one camera listener, no Area3D, no
## doppler, no emission angle): the left/right output gains, and the emitter's high-shelf gain.
func gains(e: SpatialEmitter) -> Vector2:
	e.shelf_gain = 1.0
	if not e.is_inside_tree():
		return Vector2.ZERO
	var cam := e.get_viewport().get_camera_3d()
	if cam == null:
		return Vector2.ZERO
	var local := cam.global_transform.orthonormalized().affine_inverse() * e.global_position
	var dist := local.length()
	if e.max_distance > 0.0 and dist > e.max_distance:
		return Vector2.ZERO
	var att := linear_to_db(1.0 / ((dist / e.unit_size) + CMP_EPSILON)) + e.volume_db
	att = minf(att, e.max_db)
	var multiplier := db_to_linear(att)
	if e.max_distance > 0.0:
		multiplier *= maxf(0.0, 1.0 - dist / e.max_distance)
	var db_att := (1.0 - minf(1.0, multiplier)) * e.attenuation_filter_db
	e.shelf_gain = db_to_linear(db_att)
	# _calc_output_vol_stereo
	var strength := _panning * e.panning_strength
	var flatrad := sqrt(local.x * local.x + local.z * local.z)
	var gg := clampf((1.0 - strength) * (1.0 - strength), 0.0, 1.0)
	var f := (1.0 - gg) / (1.0 + gg)
	var cosx := clampf(local.x / (1.0 if flatrad == 0.0 else flatrad), -1.0, 1.0)
	var fcosx := cosx * f
	return Vector2(sqrt((-fcosx + 1.0) / 2.0), sqrt((fcosx + 1.0) / 2.0)) * multiplier


func _process(_dt: float) -> void:
	for dest in _groups:
		for v: Voice in _groups[dest]:
			if v.emitter == null:
				continue
			if not is_instance_valid(v.emitter) or not v.emitter.is_inside_tree():
				release(v)
				continue
			if not v.player.playing and not v.player.stream_paused:
				# (A one-shot ended.)
				v.emitter._voice = null
				release(v)
				continue
			apply(v, v.emitter)


## Voices in use (tests and diagnostics).
func active_voices() -> int:
	var n := 0
	for dest in _groups:
		for v: Voice in _groups[dest]:
			n += 1 if v.emitter != null else 0
	return n
