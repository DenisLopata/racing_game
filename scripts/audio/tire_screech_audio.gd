class_name TireScreechAudio
extends Node
## Procedural tire screech sound system that responds to slip angle and speed

# Audio player
var screech_player: AudioStreamPlayer

# Audio generation parameters
var sample_rate: float = 44100.0
var _phase: float = 0.0

# Current state
var current_slip_angle: float = 0.0
var current_speed: float = 0.0
var is_screeching: bool = false
var screech_intensity: float = 0.0

# Thresholds
var min_slip_angle: float = 10.0  # Minimum slip angle to start screeching
var max_slip_angle: float = 45.0  # Slip angle for maximum screech
var min_speed: float = 30.0       # Minimum speed for screech

# Volume settings
var base_volume_db: float = -20.0
var max_volume_db: float = -8.0
var master_volume: float = 1.0

# Screech characteristics
var base_frequency: float = 800.0     # Base screech frequency
var frequency_variance: float = 200.0 # Random variance
var noise_amount: float = 0.6         # Amount of noise in screech

# Playback
var playback: AudioStreamGeneratorPlayback

func _ready() -> void:
	_setup_audio_player()

func _setup_audio_player() -> void:
	screech_player = AudioStreamPlayer.new()
	screech_player.name = "ScreechPlayer"
	screech_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"

	var stream = AudioStreamGenerator.new()
	stream.mix_rate = sample_rate
	stream.buffer_length = 0.1
	screech_player.stream = stream
	add_child(screech_player)

func _process(delta: float) -> void:
	_update_screech_state(delta)
	if is_screeching:
		_fill_audio_buffer()

func start() -> void:
	screech_player.play()
	playback = screech_player.get_stream_playback()

func stop() -> void:
	screech_player.stop()
	is_screeching = false
	screech_intensity = 0.0

## Update tire state
func update(slip_angle: float, speed: float) -> void:
	current_slip_angle = abs(slip_angle)
	current_speed = abs(speed)

func _update_screech_state(delta: float) -> void:
	# Determine if we should be screeching
	var should_screech = current_slip_angle > min_slip_angle and current_speed > min_speed

	# Target intensity based on slip angle
	var target_intensity: float = 0.0
	if should_screech:
		var slip_factor = clampf((current_slip_angle - min_slip_angle) / (max_slip_angle - min_slip_angle), 0.0, 1.0)
		var speed_factor = clampf((current_speed - min_speed) / 150.0, 0.3, 1.0)
		target_intensity = slip_factor * speed_factor

	# Smooth transition
	screech_intensity = lerpf(screech_intensity, target_intensity, delta * 8.0)

	# Update playing state
	if screech_intensity > 0.05 and not is_screeching:
		is_screeching = true
		if not screech_player.playing:
			start()
	elif screech_intensity <= 0.05 and is_screeching:
		is_screeching = false

	# Update volume
	var target_volume = lerpf(base_volume_db, max_volume_db, screech_intensity)
	screech_player.volume_db = target_volume * master_volume

func _fill_audio_buffer() -> void:
	if not playback or not playback.can_push_buffer(512):
		return

	var frames_available = playback.get_frames_available()
	if frames_available < 1:
		return

	# Calculate frequency based on speed (higher speed = higher pitch)
	var speed_pitch = 1.0 + (current_speed / 300.0) * 0.3
	var frequency = base_frequency * speed_pitch

	# Add some random variation
	var time_variation = sin(Time.get_ticks_msec() * 0.005) * frequency_variance * 0.5
	frequency += time_variation

	var increment = frequency / sample_rate

	# Generate audio frames
	var frames = PackedVector2Array()
	frames.resize(frames_available)

	for i in frames_available:
		_phase += increment
		if _phase > 1.0:
			_phase -= 1.0

		var sample = _generate_screech_sample(_phase)

		# Apply intensity envelope
		sample *= screech_intensity

		frames[i] = Vector2(sample, sample)

	playback.push_buffer(frames)

func _generate_screech_sample(phase: float) -> float:
	# Combination of filtered noise and tonal content for tire screech

	# Noise component (primary screech sound)
	var noise = (randf() - 0.5) * 2.0 * noise_amount

	# Tonal components (metallic quality)
	var tone1 = sin(phase * TAU) * 0.3
	var tone2 = sin(phase * TAU * 2.3) * 0.15  # Inharmonic for realism
	var tone3 = sin(phase * TAU * 3.7) * 0.1   # Another inharmonic

	# Combine
	var sample = noise + tone1 + tone2 + tone3

	# Add some "grip-slip" stuttering effect at high slip angles
	if current_slip_angle > 30.0:
		var stutter = sin(phase * TAU * 12.0)
		if stutter > 0.5:
			sample *= 0.7

	return clampf(sample * 0.5, -1.0, 1.0)

## Set master volume (0.0 to 1.0)
func set_master_volume(volume: float) -> void:
	master_volume = clampf(volume, 0.0, 1.0)

## Configure screech characteristics for different tire types
func configure(tire_type: String) -> void:
	match tire_type:
		"stock":
			base_frequency = 800.0
			noise_amount = 0.6
			min_slip_angle = 12.0
		"sport":
			base_frequency = 900.0
			noise_amount = 0.5
			min_slip_angle = 15.0
		"drift":
			base_frequency = 750.0
			noise_amount = 0.7
			min_slip_angle = 8.0  # Screeches easier
		"racing":
			base_frequency = 1000.0
			noise_amount = 0.4
			min_slip_angle = 18.0
		"offroad":
			base_frequency = 600.0
			noise_amount = 0.8
			min_slip_angle = 20.0
		_:
			pass
