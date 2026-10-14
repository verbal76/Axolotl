class_name AudioDirector
extends Node
## Music that heals with the environment, the aquarium's own soundscape, and muffled bedroom
## sounds that are MORE noticeable while the tank is murky and recede as it clears.

signal outside_event(kind: String)

## The owner's two songs, played one after the other on the title and every moss ball.
const SONGS: Array[String] = [
	"res://assets/audio/music_aquarium_whimsy.ogg",
	"res://assets/audio/music_bubbly_underworld.ogg",
]
const SONG_DB := -1.5
## Music lowpass: clear on the title; in play it runs from MURKY_HZ on a murky ball to CLEAR_HZ
## on a healed one. The songs stay recognisable when murky (the old 750 Hz floor hid them).
const CLEAR_HZ := 18000.0
const MURKY_HZ := 2200.0

var song_index := 0
var _song: AudioStreamPlayer
var _songs: Array[AudioStream] = []
## Where the music lowpass is heading; the cutoff glides there (see _glide_cutoff).
var cutoff_target := CLEAR_HZ
var _lowpass: AudioEffectLowPassFilter
var _out_lowpass: AudioEffectLowPassFilter
var _water: AudioStreamPlayer
var _aerator: AudioStreamPlayer
## The aquarium bed's levels (dB). It fades in at launch, eases under the music once the title's
## songs start, and in play follows update_mix; every change glides (BED_GLIDE dB/s), never jumps.
const WATER_DB := -12.0
const AERATOR_DB := -17.0
const BED_UNDER_MUSIC_DB := -3.0
const BED_FADE_IN := 1.5
const BED_GLIDE := 4.0
var _water_target := WATER_DB
var _aerator_target := AERATOR_DB
var _bed_in := 0.0
## The bed's gliding levels (their level buses follow them).
var _water_db := -80.0
var _aerator_db := -80.0
var _life: AudioStreamPlayer
var _travel: AudioStreamPlayer
var _outside: AudioStreamPlayer
var _out_timer := 12.0
var _g := 0.0
var _started := false


func _enter_tree() -> void:
	_setup_buses()


## Per-source level buses (2026-10-13, ledger row 37): the ambience bed, the life layer and the travel
## whoosh change level while they play. A playing player's volume_db write makes Godot 4.7.2 replace its
## routing data and free the old copy unsynchronised with the audio thread (see SpatialAudio), so
## their players keep a fixed volume and each level is its bus's volume (a plain value, nothing freed).
const LEVEL_BUSES := {"Bed.Water": "Ambience", "Bed.Aerator": "Ambience", "Bed.Life": "Ambience", "Travel": "SFX"}
const SILENT_DB := -80.0


func _setup_buses() -> void:
	# Idempotent (a reloaded scene or an interrupted earlier setup): each bus and its effects are
	# created only if missing, so a second AudioDirector never duplicates them. Bus layout changes are
	# not synchronised with the mix in 4.7.2 (AudioServer.add_bus takes no lock): made with the audio
	# driver locked, once, during loading.
	var created := false
	AudioServer.lock()
	for bus_name in ["Music", "SFX", "Ambience", "Outside"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master" if bus_name in ["Music", "SFX"] else "SFX")
		created = true
	for bus_name in LEVEL_BUSES:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, LEVEL_BUSES[bus_name])
		AudioServer.set_bus_volume_db(i, SILENT_DB)
	var mi := AudioServer.get_bus_index("Music")
	if AudioServer.get_bus_effect_count(mi) == 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = CLEAR_HZ
		AudioServer.add_bus_effect(mi, lp)
	_lowpass = AudioServer.get_bus_effect(mi, 0)
	var oi := AudioServer.get_bus_index("Outside")
	if AudioServer.get_bus_effect_count(oi) == 0:
		var olp := AudioEffectLowPassFilter.new()
		olp.cutoff_hz = 1600.0
		AudioServer.add_bus_effect(oi, olp)
		var rev := AudioEffectReverb.new()
		rev.room_size = 0.6
		rev.wet = 0.25
		AudioServer.add_bus_effect(oi, rev)
	_out_lowpass = AudioServer.get_bus_effect(oi, 0)
	AudioServer.unlock()
	if created:
		Settings.apply_audio()


## A level bus's volume (its source's level).
static func bus_db(bus_name: String) -> float:
	var i := AudioServer.get_bus_index(bus_name)
	return AudioServer.get_bus_volume_db(i) if i >= 0 else SILENT_DB


static func set_bus_db(bus_name: String, db: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, db)


func _ready() -> void:
	for path in SONGS:
		_songs.append(_load(path))
	_song = AudioStreamPlayer.new()
	_song.bus = "Music"
	_song.volume_db = SONG_DB
	_song.finished.connect(next_song)
	add_child(_song)
	# The household-aquarium bed, heard from the loading screen on (two co-prime loops; see
	# tools/gen_audio.py aquarium_bed): it starts silent and fades in over BED_FADE_IN.
	_water = _loop_player("res://assets/audio/amb_water.wav", "Bed.Water", SILENT_DB)
	_aerator = _loop_player("res://assets/audio/amb_aerator.wav", "Bed.Aerator", SILENT_DB)
	_life = _loop_player("res://assets/audio/amb_life.wav", "Bed.Life", -40.0)
	_travel = _loop_player("res://assets/audio/amb_travel.wav", "Travel", SILENT_DB, false)
	_outside = AudioStreamPlayer.new()
	_outside.bus = "Outside"
	add_child(_outside)


func _load(path: String) -> AudioStream:
	return load(path) if ResourceLoader.exists(path) else null


## A player on its own level bus: the player's volume stays 0 dB; `db` is the bus's starting level.
func _loop_player(path: String, bus: String, db: float, autoplay := true) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.stream = _load(path)
	set_bus_db(bus, db)
	add_child(p)
	if autoplay and p.stream:
		p.play()
	return p


## Every moss ball shares the songs: arriving on a ball starts the music if it is not already
## playing, and never restarts a song that is (travelling between balls keeps it going).
func set_ball(_i: int, _fade: bool) -> void:
	if not _song.playing:
		_play_song(song_index)
		# (The songs take the lead: the bed eases a little under them.)
		_water_target = WATER_DB + BED_UNDER_MUSIC_DB
		_aerator_target = AERATOR_DB + BED_UNDER_MUSIC_DB
	_started = true


## The song after the current one (called when a song ends; the two alternate).
func next_song() -> void:
	_play_song((song_index + 1) % SONGS.size())


func current_song() -> AudioStream:
	return _song.stream


func _play_song(i: int) -> void:
	song_index = i
	_song.stream = _songs[i]
	if _song.stream:
		_song.play()


func travel_whoosh(on: bool) -> void:
	if _travel.stream == null:
		return
	if on:
		set_bus_db("Travel", -4.0)
		_travel.play()
	else:
		var tw := create_tween()
		tw.tween_method(func(db: float) -> void: set_bus_db("Travel", db), bus_db("Travel"), -60.0, 0.8)
		tw.tween_callback(_travel.stop)


## ball_r: displayed restoration per ball (0..1); g: displayed total restoration.
func update_mix(ball_r: Array[float], g: float, current: int) -> void:
	_g = g
	# Clarity: the music is muffled while the current ball is murky and opens up as it heals.
	var rc: float = ball_r[current]
	cutoff_target = lerpf(MURKY_HZ, CLEAR_HZ, pow(rc, 1.4))
	# The aquarium's own soundscape grows; outside sounds recede.
	_water_target = lerpf(-13.0, -10.0, g) + BED_UNDER_MUSIC_DB
	_aerator_target = lerpf(-18.0, -15.0, g) + BED_UNDER_MUSIC_DB
	set_bus_db("Bed.Life", linear_to_db(maxf(0.0001, g * 0.55)))
	var ob := AudioServer.get_bus_index("Outside")
	if ob >= 0:
		AudioServer.set_bus_volume_db(ob, lerpf(-3.0, -22.0, pow(g, 0.8)))
	if _out_lowpass:
		_out_lowpass.cutoff_hz = lerpf(1600.0, 900.0, g)


## Glides the music lowpass toward cutoff_target (on a log scale, ~1.5 s for the full range), so
## leaving the title or arriving on another ball never snaps the sound.
func _glide_cutoff(dt: float) -> void:
	if _lowpass == null:
		return
	var target := cutoff_target if Game.inst != null and Game.inst.state == "play" else CLEAR_HZ
	var l := log(_lowpass.cutoff_hz)
	_lowpass.cutoff_hz = exp(move_toward(l, log(target), dt * 1.4))


## The bed's level: a linear fade-in from silence at launch, then gliding toward its targets.
func bed_levels() -> Vector2:
	return Vector2(_water_db, _aerator_db)


func _glide_bed(dt: float) -> void:
	if _bed_in < 1.0:
		_bed_in = minf(1.0, _bed_in + dt / BED_FADE_IN)
		var k := linear_to_db(maxf(0.0001, _bed_in))
		_water_db = _water_target + k
		_aerator_db = _aerator_target + k
	else:
		_water_db = move_toward(_water_db, _water_target, BED_GLIDE * dt)
		_aerator_db = move_toward(_aerator_db, _aerator_target, BED_GLIDE * dt)
	set_bus_db("Bed.Water", _water_db)
	set_bus_db("Bed.Aerator", _aerator_db)


## Looping positional sources play only within earshot (2026-10-13). A SpatialEmitter holds a voice
## (SpatialAudio) while it plays, and voices are few: a bubbler or a vortex rush far away is silent
## (beyond its max_distance) and needs none. Its owner says whether it wants to play (want_loop); this
## decides when it actually does: it starts RANGE_RESUME_M before its audible edge (still silent there,
## so nothing is heard starting) and stops RANGE_STOP_M beyond it (hysteresis). What is heard is
## unchanged. (Measured at each ball's start: 14-15 looping sources playing, 12-15 of them out of
## earshot, now 1-2. An earlier note here said those out-of-earshot AudioStreamPlayer3Ds swapped
## routing data every tick; the engine skips that beyond max_distance, so they did not.)
const RANGE_GROUP := "range_gated_audio"
const RANGE_RESUME_M := 6.0
const RANGE_STOP_M := 12.0
const RANGE_PERIOD := 0.2
var _range_t := 0.0


## The owner's wish for a looping 3D source (vortex rush, bubbler): on = play whenever within earshot.
static func want_loop(p: SpatialEmitter, on: bool) -> void:
	if p == null or not is_instance_valid(p):
		return
	if not p.is_in_group(RANGE_GROUP):
		p.add_to_group(RANGE_GROUP)
	p.set_meta("want_play", on)
	if not on:
		if p.playing:
			p.stop()
	elif not p.playing and p.stream != null and p.is_inside_tree() and in_earshot(p, RANGE_RESUME_M):
		p.play()


## Whether the listener (the current camera) is within the player's max_distance plus `margin`.
## With no camera to measure from, it counts as near (behaves as before).
static func in_earshot(p: SpatialEmitter, margin: float) -> bool:
	if not p.is_inside_tree() or p.max_distance <= 0.0:
		return true
	var cam := p.get_viewport().get_camera_3d()
	if cam == null:
		return true
	return cam.global_position.distance_to(p.global_position) <= p.max_distance + margin


func _gate_ranges() -> void:
	for n in get_tree().get_nodes_in_group(RANGE_GROUP):
		var p := n as SpatialEmitter
		if p == null or not p.is_inside_tree() or p.stream == null:
			continue
		if not bool(p.get_meta("want_play", false)):
			if p.playing:
				p.stop()
		elif p.playing:
			if not in_earshot(p, RANGE_STOP_M):
				p.stop()
		elif in_earshot(p, RANGE_RESUME_M):
			p.play()


func _process(dt: float) -> void:
	_glide_cutoff(dt)
	_glide_bed(dt)
	_range_t -= dt
	if _range_t <= 0.0:
		_range_t = RANGE_PERIOD
		_gate_ranges()
	if not _started or Game.inst == null or Game.inst.state != "play":
		return
	_out_timer -= dt
	if _out_timer <= 0.0:
		# Unidentified sounds from the room beyond the glass.
		_out_timer = randf_range(20.0, 42.0)
		var kinds := ["footsteps", "drawer", "door", "place", "footsteps"]
		var k: String = kinds[randi() % kinds.size()]
		var s := _load("res://assets/audio/out_%s.wav" % k)
		if s:
			_outside.stream = s
			_outside.pitch_scale = randf_range(0.92, 1.05)
			_outside.play()
		outside_event.emit(k)
		if k == "footsteps":
			Game.inst.aquarium.play_legs()
		elif k == "place" and randf() < 0.5:
			Game.inst.aquarium.play_hand()
