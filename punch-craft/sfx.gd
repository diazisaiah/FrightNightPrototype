extends Node
## Placeholder sound effects (autoloaded as Sfx), synthesized at startup so the
## project needs no audio files. Swap any entry in _ready() for a recorded
## sound with load("res://sounds/....wav") later.

const MIX_RATE := 22050
const POOL_SIZE := 12
const POOL_3D_SIZE := 12

var _streams := {}
## Per-sound volume trim in dB (the Sound Lab sets these while auditioning).
var gain := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _next := 0
var _next_3d := 0
var _ambience: AudioStreamPlayer
## The soundtrack: one looping track under everything, from the first click on.
## The soundtrack: one looping track per place (audio_lab/make_tracks.py),
## crossfading as you move between them. [path, volume_db].
const MUSIC := {
	"title": ["res://music/title.wav", -1.0],
	"camp": ["res://music/camp.wav", 2.0],
	"arena": ["res://music/arena.wav", -2.0],
	"crypt": ["res://music/crypt.wav", -1.0],
	"league": ["res://music/league.wav", -2.0],
}
const MUSIC_FADE := 1.4
## Two players so tracks can crossfade.
var _music: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_track := ""
var _music_fade: Tween
## The track asked for before the browser allowed sound (first click).
var _wanted_track := "title"
var _ambience_tween: Tween
var _audio_unlocked := not OS.has_feature("web")
var _pending_ambience := {}

# Running state for the generators below, reset for each sound.
var _phase := 0.0
var _phase2 := 0.0
var _lowpass := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_streams = {
		"hit": _make(0.14, _thump.bind(150.0, 60.0, 18.0, 0.6, 60.0)),
		"heavy": _make(0.26, _thump.bind(120.0, 40.0, 11.0, 0.9, 30.0)),
		"counter": _make(0.4, _counter),
		"block": _make(0.35, _clank),
		"whoosh": _make(0.18, _whoosh),
		"slip": _make(0.4, _whoosh),
		"hurt": _make(0.25, _hurt),
		"death": _make(0.5, _thump.bind(110.0, 30.0, 6.0, 0.8, 10.0)),
		"growl": _make(0.6, _growl),
		"draw": _make(0.5, _creak),
		"twang": _make(0.3, _twang),
		"coin": _make(0.2, _coin),
		"wave": _make(2.0, _gong),
		"clear": _make(0.9, _chime),
		"fire": _make(0.6, _fire),
		"zap": _make(0.3, _zap),
		"quake": _make(0.8, _thump.bind(70.0, 22.0, 4.0, 0.9, 5.0)),
		"tell": _make(0.25, _tell),
		"heal": _make(0.7, _heal),
		"tick": _make(0.05, _tick),
		"unlock": _make(1.3, _unlock),
		"deny": _make(0.22, _deny),
		"bell": _make(1.6, _ring_bell),
		"bleep": _make(0.42, _bleep),
	}
	_streams["wind"] = _make_loop(6.0, _wind)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Ambience"
	add_child(_ambience)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = "Music"
	add_child(_music_b)
	if _audio_unlocked:
		_start_music()
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Effects"
		add_child(player)
		_pool.append(player)
	for i in POOL_3D_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.unit_size = 6.0
		player.max_distance = 60.0
		player.bus = "Effects"
		add_child(player)
		_pool_3d.append(player)


## Browsers block audio until a real click, tap or key press. Starting the
## queued ambience directly in that input callback satisfies Safari as well as
## Chromium-based browsers.
func _input(event: InputEvent) -> void:
	if _audio_unlocked or not _is_unlock_event(event):
		return
	_audio_unlocked = true
	_start_music()
	if not _pending_ambience.is_empty():
		var pending := _pending_ambience.duplicate()
		_pending_ambience.clear()
		_play_ambience_now(pending.sound, pending.volume_db, pending.pitch)


func _is_unlock_event(event: InputEvent) -> bool:
	return ((event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventScreenTouch)
		and event.pressed)


func _start_music() -> void:
	play_music(_wanted_track)


## Switches the soundtrack to a place's track ("title", "camp", "arena",
## "crypt", "league"), crossfading. The same track keeps playing.
func play_music(track: String) -> void:
	_wanted_track = track
	if not _audio_unlocked or track == _music_track or not MUSIC.has(track):
		return
	var path: String = MUSIC[track][0]
	if not ResourceLoader.exists(path):
		return
	_music_track = track
	var old := _music
	_music = _music_b
	_music_b = old
	_music.stream = load(path)
	_music.volume_db = -40.0
	_music.play()
	# A new switch takes over from a crossfade still running.
	if _music_fade:
		_music_fade.kill()
	_music_fade = create_tween().set_parallel()
	_music_fade.tween_property(_music, "volume_db", float(MUSIC[track][1]), MUSIC_FADE)
	if old.playing:
		_music_fade.tween_property(old, "volume_db", -40.0, MUSIC_FADE)
		_music_fade.chain().tween_callback(func() -> void:
			if old != _music:
				old.stop())


## Plays a sound with no position. Pitch varies slightly so repeats don't sound identical.
func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _audio_unlocked:
		return
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	_start(player, sound, volume_db, pitch)


## Plays a sound from a point in the world, so you can hear where it came from.
func play_at(sound: String, at: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if not _audio_unlocked:
		return
	var player := _pool_3d[_next_3d]
	_next_3d = (_next_3d + 1) % _pool_3d.size()
	player.global_position = at
	_start(player, sound, volume_db, pitch)


## Starts (or changes) the looping background sound, fading in.
func play_ambience(sound: String, volume_db := -10.0, pitch := 1.0) -> void:
	if not _audio_unlocked:
		_pending_ambience = {"sound": sound, "volume_db": volume_db, "pitch": pitch}
		return
	_play_ambience_now(sound, volume_db, pitch)


func _play_ambience_now(sound: String, volume_db: float, pitch: float) -> void:
	if _ambience_tween:
		_ambience_tween.kill()
	if _ambience.stream != _streams[sound] or not _ambience.playing:
		_ambience.stream = _streams[sound]
		_ambience.volume_db = -40.0
		_ambience.play()
	_ambience.pitch_scale = pitch
	_ambience_tween = create_tween()
	_ambience_tween.tween_property(_ambience, "volume_db", volume_db, 1.5)


func stop_ambience() -> void:
	_pending_ambience.clear()
	if _ambience_tween:
		_ambience_tween.kill()
	_ambience_tween = create_tween()
	_ambience_tween.tween_property(_ambience, "volume_db", -40.0, 0.8)
	_ambience_tween.tween_callback(_ambience.stop)


func _start(player: Node, sound: String, volume_db: float, pitch: float) -> void:
	player.stream = _streams[sound]
	player.volume_db = volume_db + gain.get(sound, 0.0)
	player.pitch_scale = pitch * randf_range(0.93, 1.07)
	player.play()


## Swaps the sound used for a name (the Sound Lab auditions files this way).
func set_stream(sound: String, audio: AudioStream, gain_db := 0.0) -> void:
	_streams[sound] = audio
	gain[sound] = gain_db


func stream(sound: String) -> AudioStream:
	return _streams.get(sound)


func sounds() -> Array:
	return _streams.keys()


func _make(duration: float, generator: Callable) -> AudioStreamWAV:
	_phase = 0.0
	_phase2 = 0.0
	_lowpass = 0.0
	var count := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var peak := 0.001
	for i in count:
		var value: float = generator.call(float(i) / MIX_RATE, duration)
		samples[i] = value
		peak = maxf(peak, absf(value))
	var data := PackedByteArray()
	data.resize(count * 2)
	var fade_samples := int(0.005 * MIX_RATE)
	for i in count:
		var fade := minf(1.0, float(count - i) / fade_samples)
		data.encode_s16(i * 2, int(clampf(samples[i] / peak * 0.9 * fade, -1.0, 1.0) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = data
	return stream


## A seamless loop: renders a little extra and crossfades the tail into the head.
func _make_loop(duration: float, generator: Callable) -> AudioStreamWAV:
	_phase = 0.0
	_phase2 = 0.0
	_lowpass = 0.0
	var count := int(duration * MIX_RATE)
	var overlap := int(0.5 * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count + overlap)
	for i in count + overlap:
		samples[i] = generator.call(float(i) / MIX_RATE, duration)
	for i in overlap:
		var blend := float(i) / overlap
		samples[i] = lerpf(samples[count + i], samples[i], blend)
	var peak := 0.001
	for i in count:
		peak = maxf(peak, absf(samples[i]))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(samples[i] / peak * 0.8, -1.0, 1.0) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream


# --- Generators: (t, duration) -> sample ------------------------------------------

## Night wind: soft filtered noise that swells and dies, with a faint whistle.
func _wind(t: float, duration: float) -> float:
	var swell := 0.55 + 0.3 * sin(TAU * t / duration) + 0.15 * sin(TAU * 3.0 * t / duration + 1.3)
	var gust := _noise(0.02 + 0.03 * swell) * swell
	_phase2 += TAU * (420.0 + 80.0 * sin(TAU * 2.0 * t / duration)) / MIX_RATE
	return gust + sin(_phase2) * 0.04 * swell * swell

func _noise(smoothing: float) -> float:
	_lowpass = lerpf(_lowpass, randf_range(-1.0, 1.0), smoothing)
	return _lowpass


## Pitch-dropping body plus a burst of filtered noise: punches, deaths.
func _thump(t: float, duration: float, freq_start: float, freq_end: float, body_decay: float, noise_amount: float, noise_decay: float) -> float:
	_phase += TAU * lerpf(freq_start, freq_end, t / duration) / MIX_RATE
	return sin(_phase) * exp(-t * body_decay) + _noise(0.35) * noise_amount * exp(-t * noise_decay)


func _counter(t: float, duration: float) -> float:
	var crack := randf_range(-1.0, 1.0) * exp(-t * 70.0)
	return _thump(t, duration, 170.0, 35.0, 8.0, 0.8, 22.0) + crack * 0.8


func _clank(t: float, _duration: float) -> float:
	var ring := sin(TAU * 820.0 * t) + 0.7 * sin(TAU * 1290.0 * t) + 0.5 * sin(TAU * 2150.0 * t)
	return ring * exp(-t * 14.0) * 0.5 + randf_range(-1.0, 1.0) * exp(-t * 200.0)


func _whoosh(t: float, duration: float) -> float:
	var progress := t / duration
	return _noise(lerpf(0.05, 0.25, sin(PI * progress))) * sin(PI * progress)


func _hurt(t: float, duration: float) -> float:
	return clampf(_thump(t, duration, 95.0, 45.0, 9.0, 0.7, 18.0) * 2.0, -1.0, 1.0)


func _growl(t: float, duration: float) -> float:
	var envelope := sin(PI * t / duration)
	var tremolo := 1.0 + 0.5 * sin(TAU * 9.0 * t)
	var saw := fmod(t * 65.0, 1.0) * 2.0 - 1.0
	var saw2 := fmod(t * 97.0, 1.0) * 2.0 - 1.0
	_lowpass = lerpf(_lowpass, saw + saw2 * 0.5 + randf_range(-0.3, 0.3), 0.15)
	return _lowpass * envelope * tremolo


func _creak(t: float, duration: float) -> float:
	var crackle := 1.0 if sin(TAU * lerpf(18.0, 40.0, t / duration) * t) > 0.6 else 0.15
	return _noise(0.2) * crackle * (t / duration)


func _twang(t: float, _duration: float) -> float:
	_phase += TAU * (230.0 - t * 120.0) / MIX_RATE
	return (sin(_phase) + 0.4 * sin(_phase * 1.5)) * exp(-t * 12.0) + randf_range(-1.0, 1.0) * exp(-t * 150.0) * 0.5


func _coin(t: float, _duration: float) -> float:
	var freq := 1568.0 if t < 0.06 else 2093.0
	var start := 0.0 if t < 0.06 else 0.06
	return sin(TAU * freq * t) * exp(-(t - start) * 25.0)


func _gong(t: float, _duration: float) -> float:
	var tone := sin(TAU * 98.0 * t) + 0.6 * sin(TAU * 147.5 * t) + 0.4 * sin(TAU * 198.0 * t) + 0.25 * sin(TAU * 249.0 * t)
	return tone * exp(-t * 2.2) * minf(1.0, t * 80.0)


## The TV censor beep over Tony's language.
func _bleep(t: float, duration: float) -> float:
	return sin(TAU * 1000.0 * t) * 0.5 * minf(1.0, t * 200.0) * minf(1.0, (duration - t) * 200.0)


## The ring bell: three quick strikes that ring out.
func _ring_bell(t: float, _duration: float) -> float:
	var total := 0.0
	for strike in [0.0, 0.22, 0.44]:
		var s: float = t - strike
		if s < 0.0:
			continue
		var tone := sin(TAU * 1180.0 * s) + 0.5 * sin(TAU * 2950.0 * s) + 0.3 * sin(TAU * 3870.0 * s)
		total += tone * exp(-s * 3.5) * minf(1.0, s * 400.0)
	return total * 0.45


func _fire(t: float, duration: float) -> float:
	var envelope := minf(1.0, t * 30.0) * exp(-t * 4.0)
	var crackle := randf_range(-1.0, 1.0) * (1.0 if randf() < 0.03 else 0.0)
	return (_noise(0.12) * 0.8 + crackle) * envelope + sin(TAU * 55.0 * t) * exp(-t * 8.0) * 0.4


func _zap(t: float, _duration: float) -> float:
	var buzz := 1.0 if fmod(t * lerpf(1400.0, 600.0, t / 0.3), 1.0) < 0.5 else -1.0
	return (buzz * 0.5 + randf_range(-1.0, 1.0) * 0.5) * exp(-t * 12.0)


## Short bright ring: an enemy attack is wound up and about to land.
func _tell(t: float, _duration: float) -> float:
	return (sin(TAU * 1760.0 * t) + 0.5 * sin(TAU * 2640.0 * t)) * exp(-t * 22.0)


## Rising shimmer: a Grave Priest heals.
func _heal(t: float, duration: float) -> float:
	var freq := lerpf(400.0, 900.0, t / duration)
	_phase += TAU * freq / MIX_RATE
	return (sin(_phase) + 0.3 * sin(_phase * 2.0)) * sin(PI * t / duration) * (0.7 + 0.3 * sin(TAU * 12.0 * t))


func _chime(t: float, _duration: float) -> float:
	var value := 0.0
	var notes := [523.25, 659.25, 783.99]
	for i in notes.size():
		var start := i * 0.1
		if t >= start:
			value += sin(TAU * notes[i] * (t - start)) * exp(-(t - start) * 6.0)
	return value


## A tiny wooden click: hovering a node or button.
func _tick(t: float, _duration: float) -> float:
	return (sin(TAU * 2400.0 * t) * 0.6 + randf_range(-1.0, 1.0) * 0.4) * exp(-t * 160.0)


## A power awakens: a low boom under a rising, ringing chord.
func _unlock(t: float, duration: float) -> float:
	_phase += TAU * lerpf(90.0, 45.0, t / duration) / MIX_RATE
	var boom := sin(_phase) * exp(-t * 5.0) * 0.9
	var value := 0.0
	var notes := [392.0, 493.88, 587.33, 783.99]
	for i in notes.size():
		var start := 0.05 + i * 0.07
		if t >= start:
			value += sin(TAU * notes[i] * (t - start)) * exp(-(t - start) * 3.0) * 0.45
	var shimmer := sin(TAU * 1567.98 * t) * 0.12 * sin(PI * t / duration) * (0.5 + 0.5 * sin(TAU * 14.0 * t))
	return boom + value + shimmer


## A dull double buzz: can't buy that.
func _deny(t: float, _duration: float) -> float:
	var gate := 1.0 if t < 0.08 or (t > 0.11 and t < 0.19) else 0.0
	var buzz := 1.0 if fmod(t * 140.0, 1.0) < 0.5 else -1.0
	return buzz * gate * 0.5 + sin(TAU * 140.0 * t) * gate * 0.5
