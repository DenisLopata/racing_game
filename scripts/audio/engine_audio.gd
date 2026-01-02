class_name EngineAudio
extends Node
## Procedural engine sound system that responds to RPM and throttle

# Audio players
var engine_player: AudioStreamPlayer
var exhaust_player: AudioStreamPlayer

# Engine sound parameters
var base_frequency: float = 80.0       # Base engine frequency at idle
var max_frequency: float = 400.0       # Max frequency at redline
var current_rpm_percent: float = 0.0
var current_throttle: float = 0.0

# Exhaust pop parameters
var exhaust_pop_chance: float = 0.3    # Chance of exhaust pop on throttle lift
var last_throttle: float = 0.0

# Volume settings
var engine_volume_db: float = -10.0
var exhaust_volume_db: float = -15.0
var master_volume: float = 1.0

# Audio generation
var sample_rate: float = 44100.0
var _phase: float = 0.0
var _exhaust_phase: float = 0.0

# Playback
var playback: AudioStreamGeneratorPlayback
var exhaust_playback: AudioStreamGeneratorPlayback
var is_playing: bool = false

func _ready() -> void:
	_setup_audio_players()

func _setup_audio_players() -> void:
	# Main engine sound
	engine_player = AudioStreamPlayer.new()
	engine_player.name = "EnginePlayer"
	engine_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"

	var engine_stream = AudioStreamGenerator.new()
	engine_stream.mix_rate = sample_rate
	engine_stream.buffer_length = 0.1
	engine_player.stream = engine_stream
	add_child(engine_player)

	# Exhaust sounds (for pops and burbles)
	exhaust_player = AudioStreamPlayer.new()
	exhaust_player.name = "ExhaustPlayer"
	exhaust_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"

	var exhaust_stream = AudioStreamGenerator.new()
	exhaust_stream.mix_rate = sample_rate
	exhaust_stream.buffer_length = 0.05
	exhaust_player.stream = exhaust_stream
	add_child(exhaust_player)

func _process(delta: float) -> void:
	if is_playing:
		_fill_audio_buffer()
		_check_exhaust_pop()

func start() -> void:
	if is_playing:
		return

	engine_player.play()
	exhaust_player.play()
	playback = engine_player.get_stream_playback()
	exhaust_playback = exhaust_player.get_stream_playback()
	is_playing = true

func stop() -> void:
	is_playing = false
	engine_player.stop()
	exhaust_player.stop()

## Update engine state
func update(rpm_percent: float, throttle: float) -> void:
	last_throttle = current_throttle
	current_rpm_percent = clamp(rpm_percent, 0.0, 1.0)
	current_throttle = clamp(throttle, 0.0, 1.0)

	# Update volume based on throttle
	var target_volume = engine_volume_db + (current_throttle * 5.0)  # Louder on throttle
	engine_player.volume_db = target_volume * master_volume

func _fill_audio_buffer() -> void:
	if not playback or not playback.can_push_buffer(512):
		return

	var frames_available = playback.get_frames_available()
	if frames_available < 1:
		return

	# Calculate current frequency based on RPM
	var frequency = lerp(base_frequency, max_frequency, current_rpm_percent)

	# Add some variation for realism
	var variation = sin(Time.get_ticks_msec() * 0.01) * 5.0

	var increment = (frequency + variation) / sample_rate

	# Generate audio frames
	var frames = PackedVector2Array()
	frames.resize(frames_available)

	for i in frames_available:
		_phase += increment
		if _phase > 1.0:
			_phase -= 1.0

		# Generate engine sound (combination of harmonics)
		var sample = _generate_engine_sample(_phase)

		# Apply throttle-based filtering (more harmonics on throttle)
		sample *= 0.5 + current_throttle * 0.5

		# Apply volume envelope
		var volume = 0.3 + current_rpm_percent * 0.4

		frames[i] = Vector2(sample * volume, sample * volume)

	playback.push_buffer(frames)

func _generate_engine_sample(phase: float) -> float:
	# Fundamental frequency
	var sample = sin(phase * TAU)

	# Add harmonics for richer sound
	sample += sin(phase * TAU * 2.0) * 0.5  # 2nd harmonic
	sample += sin(phase * TAU * 3.0) * 0.25  # 3rd harmonic
	sample += sin(phase * TAU * 4.0) * 0.125  # 4th harmonic

	# Add some noise for texture
	sample += (randf() - 0.5) * 0.1 * current_throttle

	# Add "firing" pulses (simulates cylinder firing)
	var pulse_phase = fmod(phase * 4.0, 1.0)  # 4-cylinder simulation
	if pulse_phase < 0.1:
		sample += 0.3 * (1.0 - pulse_phase * 10.0)

	return clamp(sample / 2.5, -1.0, 1.0)

func _check_exhaust_pop() -> void:
	# Check for throttle lift (potential exhaust pop)
	if last_throttle > 0.5 and current_throttle < 0.2:
		if randf() < exhaust_pop_chance and current_rpm_percent > 0.5:
			_play_exhaust_pop()

func _play_exhaust_pop() -> void:
	if not exhaust_playback or not exhaust_playback.can_push_buffer(256):
		return

	# Generate a short exhaust pop sound
	var frames = PackedVector2Array()
	var pop_length = int(sample_rate * 0.05)  # 50ms pop
	frames.resize(pop_length)

	for i in pop_length:
		var t = float(i) / float(pop_length)
		var envelope = (1.0 - t) * (1.0 - t)  # Decay envelope

		# Noise burst with low-pass character
		var sample = (randf() - 0.5) * envelope
		sample += sin(t * 200.0) * envelope * 0.5  # Low rumble

		var volume = 0.5
		frames[i] = Vector2(sample * volume, sample * volume)

	exhaust_playback.push_buffer(frames)

## Set master volume (0.0 to 1.0)
func set_master_volume(volume: float) -> void:
	master_volume = clamp(volume, 0.0, 1.0)

## Configure engine sound character
func configure(engine_type: String) -> void:
	match engine_type:
		"inline4":
			base_frequency = 80.0
			max_frequency = 350.0
		"v6":
			base_frequency = 70.0
			max_frequency = 400.0
		"v8":
			base_frequency = 60.0
			max_frequency = 450.0
			exhaust_pop_chance = 0.5
		"electric":
			base_frequency = 200.0
			max_frequency = 800.0
			exhaust_pop_chance = 0.0  # No exhaust pops for electric
		_:
			pass
