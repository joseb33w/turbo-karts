extends Node
## Procedural sound for Turbo Karts. All audio is synthesized into AudioStreamWAV
## at runtime (no binary assets) so the export .pck stays tiny. The engine is a
## seamless looping tone whose pitch_scale rises with speed (the "whoosh"); drift
## is a looping hiss whose volume tracks the boost charge.

const MIX := 22050

var _engine: AudioStreamPlayer
var _drift: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0

var _s_boost: AudioStreamWAV
var _s_coin: AudioStreamWAV
var _s_item: AudioStreamWAV
var _s_hit: AudioStreamWAV
var _s_beep: AudioStreamWAV
var _s_go: AudioStreamWAV

var _engine_on := false


func _ready() -> void:
	_engine = AudioStreamPlayer.new()
	_engine.stream = _build_engine()
	_engine.volume_db = -10.0
	_engine.bus = "Master"
	add_child(_engine)

	_drift = AudioStreamPlayer.new()
	_drift.stream = _build_noise_loop(0.3, 1600.0)
	_drift.volume_db = -60.0
	add_child(_drift)

	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

	_s_boost = _build_boost()
	_s_coin = _build_coin()
	_s_item = _build_arp([660.0, 880.0, 1175.0], 0.24)
	_s_hit = _build_hit()
	_s_beep = _build_tone(700.0, 0.12, 0.0)
	_s_go = _build_tone(1050.0, 0.34, 9.0)


func start_engine() -> void:
	if not _engine_on:
		_engine.play()
		_drift.play()
		_engine_on = true


func set_engine(speed_ratio: float) -> void:
	if not _engine_on:
		return
	_engine.pitch_scale = clampf(0.7 + speed_ratio * 1.7, 0.6, 2.6)
	_engine.volume_db = lerpf(-16.0, -6.0, clampf(speed_ratio, 0.0, 1.0))


func set_drift(active: bool, charge: float) -> void:
	if not _engine_on:
		return
	var target := -60.0 if not active else lerpf(-26.0, -10.0, clampf(charge, 0.0, 1.0))
	_drift.volume_db = lerpf(_drift.volume_db, target, 0.25)
	_drift.pitch_scale = 0.8 + charge * 0.8


func boost() -> void:
	_play(_s_boost, 0.0)

func coin() -> void:
	_play(_s_coin, -3.0)

func item() -> void:
	_play(_s_item, -2.0)

func hit() -> void:
	_play(_s_hit, 0.0)

func beep() -> void:
	_play(_s_beep, -2.0)

func go() -> void:
	_play(_s_go, 0.0)


func _play(stream: AudioStreamWAV, vol_db: float) -> void:
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = stream
	p.volume_db = vol_db
	p.play()


func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var n := samples.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := clampf(samples[i], -1.0, 1.0)
		data.encode_s16(i * 2, int(roundi(v * 32000.0)))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w


func _build_engine() -> AudioStreamWAV:
	var dur := 0.2
	var n := int(MIX * dur)
	var base := 65.0
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / MIX
		var v := 0.5 * sin(TAU * base * t)
		v += 0.30 * sin(TAU * base * 2.0 * t + 0.4)
		v += 0.16 * sin(TAU * base * 3.0 * t)
		var ph := fposmod(base * 4.0 * t, 1.0)
		v += 0.10 * (ph * 2.0 - 1.0)
		s[i] = v * 0.7
	return _wav(s, true)


func _build_noise_loop(dur: float, cutoff: float) -> AudioStreamWAV:
	var n := int(MIX * dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	var a := clampf(cutoff / float(MIX), 0.0, 1.0)
	for i in n:
		var white := rng.randf_range(-1.0, 1.0)
		prev = lerpf(prev, white, a)
		s[i] = prev * 0.8
	return _wav(s, true)


func _build_boost() -> AudioStreamWAV:
	var dur := 0.5
	var n := int(MIX * dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / MIX
		var env := exp(-t * 5.0) * minf(1.0, t * 30.0)
		var sweep := 380.0 + 1400.0 * (t / dur)
		var noise := rng.randf_range(-1.0, 1.0)
		prev = lerpf(prev, noise, 0.35)
		var tone := sin(TAU * sweep * t)
		s[i] = (0.55 * prev + 0.45 * tone) * env
	return _wav(s, false)


func _build_coin() -> AudioStreamWAV:
	var dur := 0.18
	var n := int(MIX * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / MIX
		var f := 1318.0 if t < 0.06 else 1760.0
		var env := exp(-fposmod(t, 0.06) * 22.0)
		s[i] = sin(TAU * f * t) * env * 0.7
	return _wav(s, false)


func _build_arp(freqs: Array, dur: float) -> AudioStreamWAV:
	var n := int(MIX * dur)
	var seg := dur / float(freqs.size())
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / MIX
		var idx := mini(int(t / seg), freqs.size() - 1)
		var f: float = freqs[idx]
		var lt := t - float(idx) * seg
		var env := exp(-lt * 10.0) * minf(1.0, lt * 60.0)
		s[i] = sin(TAU * f * t) * env * 0.7
	return _wav(s, false)


func _build_hit() -> AudioStreamWAV:
	var dur := 0.45
	var n := int(MIX * dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / MIX
		var f := lerpf(420.0, 90.0, t / dur)
		var env := exp(-t * 4.5)
		var tone := sin(TAU * f * t)
		var noise := rng.randf_range(-1.0, 1.0) * exp(-t * 12.0)
		s[i] = (0.7 * tone + 0.3 * noise) * env * 0.8
	return _wav(s, false)


func _build_tone(freq: float, dur: float, vibrato: float) -> AudioStreamWAV:
	var n := int(MIX * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / MIX
		var env := minf(1.0, t * 40.0) * minf(1.0, (dur - t) * 12.0)
		var f := freq + sin(TAU * 9.0 * t) * vibrato
		s[i] = sin(TAU * f * t) * env * 0.75
	return _wav(s, false)
