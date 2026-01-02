class_name DamageAudio
extends Node
## Handles damage-related audio effects (impacts, engine sounds)
## Uses procedural audio generation - no external files needed

# Audio players
var impact_player: AudioStreamPlayer2D
var engine_damage_player: AudioStreamPlayer2D

# Engine damage sound state
var _engine_damage_active: bool = false
var _engine_health: float = 1.0
var _sputter_timer: float = 0.0
var _sputter_interval: float = 0.5

# Impact cooldown
var _impact_cooldown: float = 0.0
const IMPACT_COOLDOWN_TIME: float = 0.08

# Audio generation
var _sample_rate: float = 22050.0

func _ready() -> void:
	_setup_audio_players()

func _process(delta: float) -> void:
	_update_impact_cooldown(delta)
	_update_engine_damage_sound(delta)

## Setup audio player nodes
func _setup_audio_players() -> void:
	# Impact sound player
	impact_player = AudioStreamPlayer2D.new()
	impact_player.name = "ImpactPlayer"
	impact_player.max_distance = 500
	impact_player.attenuation = 1.5
	add_child(impact_player)

	# Engine damage player
	engine_damage_player = AudioStreamPlayer2D.new()
	engine_damage_player.name = "EngineDamagePlayer"
	engine_damage_player.max_distance = 400
	engine_damage_player.attenuation = 2.0
	add_child(engine_damage_player)

## Play impact sound based on severity
## severity: 0.0 (light tap) to 1.0 (heavy crash)
func play_impact_sound(severity: float) -> void:
	if _impact_cooldown > 0:
		return

	severity = clampf(severity, 0.0, 1.0)

	# Generate impact sound
	var sound = _generate_impact_sound(severity)
	impact_player.stream = sound
	impact_player.volume_db = lerpf(-15, -3, severity)
	impact_player.pitch_scale = lerpf(1.2, 0.7, severity)
	impact_player.play()

	_impact_cooldown = IMPACT_COOLDOWN_TIME

## Update engine damage sound based on health
func set_engine_health(health: float) -> void:
	_engine_health = clampf(health, 0.0, 1.0)
	_engine_damage_active = health < 0.5

	if not _engine_damage_active:
		engine_damage_player.stop()

## Generate procedural impact sound
func _generate_impact_sound(severity: float) -> AudioStreamWAV:
	var duration = lerpf(0.05, 0.15, severity)
	var num_samples = int(_sample_rate * duration)

	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_8_BITS
	audio.mix_rate = int(_sample_rate)
	audio.stereo = false

	var data = PackedByteArray()
	data.resize(num_samples)

	# Generate noise burst with decay
	for i in num_samples:
		var t = float(i) / num_samples
		var envelope = (1.0 - t) * (1.0 - t)  # Quadratic decay

		# Mix of noise and low frequency thump
		var noise = randf_range(-1.0, 1.0)
		var thump = sin(t * PI * 2 * lerpf(80, 40, severity))

		var sample = (noise * 0.7 + thump * 0.3) * envelope
		sample = clampf(sample, -1.0, 1.0)

		# Convert to 8-bit unsigned
		data[i] = int((sample + 1.0) * 127.5)

	audio.data = data
	return audio

## Generate engine sputter sound
func _generate_sputter_sound() -> AudioStreamWAV:
	var duration = randf_range(0.08, 0.15)
	var num_samples = int(_sample_rate * duration)

	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_8_BITS
	audio.mix_rate = int(_sample_rate)
	audio.stereo = false

	var data = PackedByteArray()
	data.resize(num_samples)

	var freq = randf_range(60, 120)

	for i in num_samples:
		var t = float(i) / _sample_rate
		var progress = float(i) / num_samples

		# Envelope: quick attack, medium decay
		var envelope = 1.0 - progress
		envelope = envelope * envelope

		# Low frequency rumble with some noise
		var wave = sin(t * PI * 2 * freq) * 0.6
		wave += sin(t * PI * 2 * freq * 2.0) * 0.2  # Harmonic
		wave += randf_range(-0.2, 0.2)  # Noise

		var sample = wave * envelope
		sample = clampf(sample, -1.0, 1.0)

		data[i] = int((sample + 1.0) * 127.5)

	audio.data = data
	return audio

## Update impact cooldown
func _update_impact_cooldown(delta: float) -> void:
	if _impact_cooldown > 0:
		_impact_cooldown -= delta

## Update engine damage sound (periodic sputtering)
func _update_engine_damage_sound(delta: float) -> void:
	if not _engine_damage_active:
		return

	_sputter_timer -= delta

	if _sputter_timer <= 0:
		# Play sputter sound
		var sound = _generate_sputter_sound()
		engine_damage_player.stream = sound

		# Volume based on damage severity
		var damage_factor = 1.0 - (_engine_health / 0.5)
		engine_damage_player.volume_db = lerpf(-18, -8, damage_factor)
		engine_damage_player.pitch_scale = randf_range(0.9, 1.1)
		engine_damage_player.play()

		# Next sputter interval (more frequent when more damaged)
		_sputter_interval = lerpf(0.8, 0.2, damage_factor)
		_sputter_timer = _sputter_interval + randf_range(-0.1, 0.1)

## Play part failure sound (big impact)
func play_part_failure_sound() -> void:
	play_impact_sound(1.0)

## Stop all sounds
func stop_all() -> void:
	impact_player.stop()
	engine_damage_player.stop()
	_engine_damage_active = false
