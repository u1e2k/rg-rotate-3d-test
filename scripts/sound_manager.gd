class_name SoundManager
extends Node

## Procedural audio generator using AudioStreamWAV for zero-dependency sound effects

static var _instance: SoundManager

func _enter_tree() -> void:
	_instance = self

static func get_instance() -> SoundManager:
	return _instance

func play_jump() -> void:
	var stream = _generate_tone_sweep(320.0, 680.0, 0.16, 0.4)
	_play_stream(stream, -6.0)

func play_shoot() -> void:
	# Laser blaster zap: high to low sweep
	var stream = _generate_tone_sweep(880.0, 220.0, 0.12, 0.45)
	_play_stream(stream, -4.0)

func play_hit() -> void:
	# Impact hit burst
	var stream = _generate_noise_burst(0.08, 0.35)
	_play_stream(stream, -6.0)

func play_explode() -> void:
	# Heavy crumbling explosion
	var stream = _generate_noise_burst(0.35, 0.5)
	_play_stream(stream, -2.0)

func play_coin() -> void:
	var stream = _generate_arpeggio([587.33, 880.0, 1174.66], 0.08, 0.35)
	_play_stream(stream, -4.0)

func play_step() -> void:
	var stream = _generate_noise_burst(0.04, 0.15)
	_play_stream(stream, -14.0)

func play_land() -> void:
	var stream = _generate_noise_burst(0.08, 0.25)
	_play_stream(stream, -10.0)

func play_respawn() -> void:
	var stream = _generate_arpeggio([440.0, 554.37, 659.25, 880.0], 0.07, 0.4)
	_play_stream(stream, -5.0)

func play_interact() -> void:
	var stream = _generate_arpeggio([523.25, 659.25, 783.99, 1046.5], 0.05, 0.35)
	_play_stream(stream, -5.0)

func play_cursor() -> void:
	# Subtle blip for menu navigation
	var stream = _generate_tone_sweep(440.0, 520.0, 0.05, 0.25)
	_play_stream(stream, -8.0)

func play_confirm() -> void:
	# Bright two-tone chime for selection
	var stream = _generate_arpeggio([523.25, 783.99], 0.07, 0.35)
	_play_stream(stream, -4.0)

func play_cancel() -> void:
	# Descending blip for back / cancel
	var stream = _generate_tone_sweep(440.0, 260.0, 0.08, 0.3)
	_play_stream(stream, -6.0)

func play_engine_rev() -> void:
	var stream = _generate_tone_sweep(180.0, 480.0, 0.3, 0.4)
	_play_stream(stream, -6.0)

func play_lockon() -> void:
	# Crisp two-tone target lock chime
	var stream = _generate_arpeggio([880.0, 1318.5], 0.06, 0.4)
	_play_stream(stream, -4.0)

func play_missile_launch() -> void:
	# Rocket booster whoosh: low frequency rising whoosh
	var stream = _generate_tone_sweep(140.0, 520.0, 0.22, 0.45)
	_play_stream(stream, -4.0)

func play_boost() -> void:
	# Space thruster ignition flare
	var stream = _generate_tone_sweep(220.0, 660.0, 0.25, 0.4)
	_play_stream(stream, -5.0)

func play_barrel_roll() -> void:
	# Aerodynamic spinning swoosh
	var stream = _generate_tone_sweep(520.0, 260.0, 0.18, 0.35)
	_play_stream(stream, -6.0)

func play_plasma() -> void:
	# Sci-fi twin plasma blaster
	var stream = _generate_tone_sweep(1050.0, 310.0, 0.09, 0.4)
	_play_stream(stream, -5.0)

func _play_stream(stream: AudioStreamWAV, volume_db: float = 0.0) -> void:
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(func(): player.queue_free())
	player.play()

func _generate_tone_sweep(f_start: float, f_end: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(total_samples)
	
	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerpf(f_start, f_end, t)
		phase += (freq * TAU) / sample_rate
		var envelope = 1.0 - t
		var wave = sin(phase) * envelope * volume
		var val = clamp(int((wave + 1.0) * 127.5), 0, 255)
		data[i] = val
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

func _generate_arpeggio(freqs: Array, note_duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var samples_per_note = int(sample_rate * note_duration)
	var total_samples = samples_per_note * freqs.size()
	var data = PackedByteArray()
	data.resize(total_samples)
	
	var idx = 0
	for f in freqs:
		var freq: float = f
		var phase = 0.0
		for i in range(samples_per_note):
			var t = float(i) / float(samples_per_note)
			phase += (freq * TAU) / sample_rate
			var envelope = 1.0 - pow(t, 0.7)
			# Square + sine mix for rich chime
			var wave = (sin(phase) * 0.7 + (1.0 if sin(phase) > 0.0 else -1.0) * 0.2) * envelope * volume
			var val = clamp(int((wave + 1.0) * 127.5), 0, 255)
			data[idx] = val
			idx += 1
			
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

func _generate_noise_burst(duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(total_samples)
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var envelope = (1.0 - t) * (1.0 - t)
		var noise = rng.randf_range(-1.0, 1.0) * envelope * volume
		var val = clamp(int((noise + 1.0) * 127.5), 0, 255)
		data[i] = val
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav
