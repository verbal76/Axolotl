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
var _life: AudioStreamPlayer
var _travel: AudioStreamPlayer
var _outside: AudioStreamPlayer
var _out_timer := 12.0
var _g := 0.0
var _started := false


func _enter_tree() -> void:
	_setup_buses()


func _setup_buses() -> void:
	if AudioServer.get_bus_index("Music") >= 0:
		_lowpass = AudioServer.get_bus_effect(AudioServer.get_bus_index("Music"), 0)
		_out_lowpass = AudioServer.get_bus_effect(AudioServer.get_bus_index("Outside"), 0)
		return
	for bus_name in ["Music", "SFX", "Ambience", "Outside"]:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master" if bus_name in ["Music", "SFX"] else "SFX")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = CLEAR_HZ
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), _lowpass)
	_out_lowpass = AudioEffectLowPassFilter.new()
	_out_lowpass.cutoff_hz = 1600.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Outside"), _out_lowpass)
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.6
	rev.wet = 0.25
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Outside"), rev)
	Settings.apply_audio()


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
	_water = _loop_player("res://assets/audio/amb_water.wav", "Ambience", -80.0)
	_aerator = _loop_player("res://assets/audio/amb_aerator.wav", "Ambience", -80.0)
	_life = _loop_player("res://assets/audio/amb_life.wav", "Ambience", -40.0)
	_travel = _loop_player("res://assets/audio/amb_travel.wav", "SFX", -80.0, false)
	_outside = AudioStreamPlayer.new()
	_outside.bus = "Outside"
	add_child(_outside)


func _load(path: String) -> AudioStream:
	return load(path) if ResourceLoader.exists(path) else null


func _loop_player(path: String, bus: String, db: float, autoplay := true) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.stream = _load(path)
	p.volume_db = db
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
		_travel.volume_db = -4.0
		_travel.play()
	else:
		var tw := create_tween()
		tw.tween_property(_travel, "volume_db", -60.0, 0.8)
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
	_life.volume_db = linear_to_db(maxf(0.0001, g * 0.55))
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
	return Vector2(_water.volume_db, _aerator.volume_db)


func _glide_bed(dt: float) -> void:
	if _bed_in < 1.0:
		_bed_in = minf(1.0, _bed_in + dt / BED_FADE_IN)
		var k := linear_to_db(maxf(0.0001, _bed_in))
		_water.volume_db = _water_target + k
		_aerator.volume_db = _aerator_target + k
		return
	_water.volume_db = move_toward(_water.volume_db, _water_target, BED_GLIDE * dt)
	_aerator.volume_db = move_toward(_aerator.volume_db, _aerator_target, BED_GLIDE * dt)


func _process(dt: float) -> void:
	_glide_cutoff(dt)
	_glide_bed(dt)
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
