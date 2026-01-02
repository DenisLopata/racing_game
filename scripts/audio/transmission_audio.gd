class_name TransmissionAudio
extends Node
## Audio effects for gear shifts and transmission sounds

# Audio players
var shift_player: AudioStreamPlayer
var backfire_player: AudioStreamPlayer

# Generation parameters
var sample_rate: float = 44100.0

# Volume settings
var shift_volume_db: float = -12.0
var backfire_volume_db: float = -8.0
var master_volume: float = 1.0

# Shift sound parameters
var shift_up_pitch: float = 1.2
var shift_down_pitch: float = 0.8
var shift_duration: float = 0.08  # 80ms click

# State tracking
var last_gear: int = 0
var pending_backfire: bool = false

func _ready() -> void:
	_setup_audio_players()

func _setup_audio_players() -> void:
	# Shift click/thunk sound
	shift_player = AudioStreamPlayer.new()
	shift_player.name = "ShiftPlayer"
	shift_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	shift_player.volume_db = shift_volume_db
	add_child(shift_player)

	# Backfire/pop on downshift
	backfire_player = AudioStreamPlayer.new()
	backfire_player.name = "BackfirePlayer"
	backfire_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	backfire_player.volume_db = backfire_volume_db
	add_child(backfire_player)

## Called when gear changes
func on_gear_change(new_gear: int, rpm_percent: float) -> void:
	if new_gear == last_gear:
		return

	var shifted_up = new_gear > last_gear

	# Play shift sound
	_play_shift_sound(shifted_up)

	# Backfire on downshift at high RPM
	if not shifted_up and rpm_percent > 0.6 and last_gear > 0:
		if randf() < 0.4:  # 40% chance
			pending_backfire = true
			# Small delay for backfire
			get_tree().create_timer(0.05).timeout.connect(_play_backfire)

	last_gear = new_gear

func _play_shift_sound(shift_up: bool) -> void:
	# Generate shift click sound
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = sample_rate
	stream.buffer_length = 0.15
	shift_player.stream = stream
	shift_player.play()

	var playback = shift_player.get_stream_playback()
	if not playback:
		return

	# Generate the shift sound
	var frames = _generate_shift_frames(shift_up)
	playback.push_buffer(frames)

func _generate_shift_frames(shift_up: bool) -> PackedVector2Array:
	var frame_count = int(sample_rate * shift_duration)
	var frames = PackedVector2Array()
	frames.resize(frame_count)

	var base_freq = 150.0 if shift_up else 120.0

	for i in frame_count:
		var t = float(i) / float(frame_count)
		var envelope = (1.0 - t) * (1.0 - t)  # Quick decay

		# Mechanical click sound
		var click = sin(t * base_freq * TAU) * envelope
		click += sin(t * base_freq * 2.5 * TAU) * envelope * 0.5

		# Add metallic transient
		if t < 0.1:
			click += (randf() - 0.5) * (1.0 - t * 10.0) * 0.8

		var sample = clampf(click * 0.6, -1.0, 1.0)
		frames[i] = Vector2(sample, sample)

	return frames

func _play_backfire() -> void:
	if not pending_backfire:
		return
	pending_backfire = false

	# Generate backfire pop sound
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = sample_rate
	stream.buffer_length = 0.2
	backfire_player.stream = stream
	backfire_player.play()

	var playback = backfire_player.get_stream_playback()
	if not playback:
		return

	var frames = _generate_backfire_frames()
	playback.push_buffer(frames)

func _generate_backfire_frames() -> PackedVector2Array:
	var pop_duration = 0.1 + randf() * 0.05  # 100-150ms
	var frame_count = int(sample_rate * pop_duration)
	var frames = PackedVector2Array()
	frames.resize(frame_count)

	var base_freq = 80.0 + randf() * 40.0  # Vary the pop frequency

	for i in frame_count:
		var t = float(i) / float(frame_count)
		var envelope = (1.0 - t) * (1.0 - t) * (1.0 - t)  # Cubic decay

		# Low frequency thump
		var sample = sin(t * base_freq * TAU) * envelope * 0.7

		# Noise burst
		sample += (randf() - 0.5) * envelope * 0.8

		# Secondary pop
		if t < 0.3:
			sample += sin(t * 200.0 * TAU) * (0.3 - t) * 0.4

		sample = clampf(sample, -1.0, 1.0)
		frames[i] = Vector2(sample, sample)

	return frames

## Set master volume
func set_master_volume(volume: float) -> void:
	master_volume = clampf(volume, 0.0, 1.0)
	shift_player.volume_db = shift_volume_db * master_volume
	backfire_player.volume_db = backfire_volume_db * master_volume

## Connect to a transmission's gear_changed signal
func connect_transmission(transmission: Transmission) -> void:
	if transmission:
		transmission.gear_changed.connect(on_gear_change)

## Configure for different transmission types
func configure(trans_type: String) -> void:
	match trans_type:
		"manual":
			shift_duration = 0.1
			shift_volume_db = -10.0
		"sequential":
			shift_duration = 0.06
			shift_volume_db = -12.0
		"dct":  # Dual-clutch
			shift_duration = 0.04
			shift_volume_db = -14.0
		"auto":
			shift_duration = 0.08
			shift_volume_db = -15.0
		_:
			pass
