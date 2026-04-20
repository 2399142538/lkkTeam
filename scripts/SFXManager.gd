extends Node


const MIX_RATE := 44100.0


func play_weapon_fire(weapon_id: String) -> void:
	match weapon_id:
		"shotgun":
			_play_tone(180.0, 0.09, -10.0, "noise")
		"flame":
			_play_tone(250.0, 0.06, -16.0, "saw")
		"arc":
			_play_tone(620.0, 0.08, -14.0, "square")
		_:
			_play_tone(330.0, 0.05, -15.0, "square")


func play_hit(weapon_id: String) -> void:
	match weapon_id:
		"shotgun":
			_play_tone(140.0, 0.05, -15.0, "noise")
		"flame":
			_play_tone(420.0, 0.04, -18.0, "saw")
		"arc":
			_play_tone(760.0, 0.05, -18.0, "square")
		_:
			_play_tone(520.0, 0.04, -18.0, "sine")


func play_player_hurt() -> void:
	_play_tone(120.0, 0.1, -12.0, "saw")


func play_chest_open() -> void:
	_play_tone(540.0, 0.08, -14.0, "sine")
	_play_tone(760.0, 0.09, -16.0, "sine")


func play_charge_pulse() -> void:
	_play_tone(240.0, 0.08, -15.0, "saw")
	_play_tone(120.0, 0.22, -13.0, "sine")


func play_boss_charge() -> void:
	_play_tone(150.0, 0.2, -12.0, "saw")
	_play_tone(320.0, 0.24, -17.0, "square")


func _play_tone(frequency: float, duration: float, volume_db: float, waveform: String) -> void:
	var player := AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = max(duration + 0.1, 0.2)
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.play()

	var playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback != null:
		var frames: int = int(MIX_RATE * duration)
		for frame_index in range(frames):
			var time := float(frame_index) / MIX_RATE
			var envelope := 1.0 - (time / duration)
			var sample := _sample_wave(waveform, time, frequency) * envelope * 0.35
			playback.push_frame(Vector2(sample, sample))

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = duration + 0.12
	timer.timeout.connect(player.queue_free)
	player.add_child(timer)
	timer.start()


func _sample_wave(waveform: String, time: float, frequency: float) -> float:
	var phase := TAU * frequency * time
	match waveform:
		"square":
			return 1.0 if sin(phase) >= 0.0 else -1.0
		"saw":
			return fmod(frequency * time, 1.0) * 2.0 - 1.0
		"noise":
			return randf_range(-1.0, 1.0)
		_:
			return sin(phase)
