class_name PositionNotifier
extends Control
## Shows toast notifications when race position changes

const NOTIFICATION_DURATION: float = 1.5
const SLIDE_DURATION: float = 0.2
const FADE_DURATION: float = 0.3

var last_position: int = -1
var notification_label: Label
var animation_tween: Tween

# Audio generation for position change sounds
var audio_player: AudioStreamPlayer

func _ready() -> void:
	# Create the notification label
	notification_label = Label.new()
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notification_label.add_theme_font_size_override("font_size", 24)
	notification_label.modulate.a = 0.0  # Start invisible
	add_child(notification_label)

	# Position at top-right of parent
	notification_label.position = Vector2(0, 0)
	notification_label.custom_minimum_size = Vector2(200, 40)

	# Create audio player for sounds
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	add_child(audio_player)

## Update position and trigger notification if changed
func update_position(new_position: int) -> void:
	# Skip if same position or first update
	if new_position == last_position:
		return

	if last_position > 0 and new_position > 0:
		var gained = new_position < last_position
		var positions_changed = abs(new_position - last_position)
		_show_notification(gained, positions_changed)

	last_position = new_position

## Show the position change notification
func _show_notification(gained: bool, positions: int) -> void:
	# Cancel any existing animation
	if animation_tween and animation_tween.is_valid():
		animation_tween.kill()

	# Set text and color
	if gained:
		if positions == 1:
			notification_label.text = "Position Gained!"
		else:
			notification_label.text = "+%d Positions!" % positions
		notification_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		if positions == 1:
			notification_label.text = "Position Lost!"
		else:
			notification_label.text = "-%d Positions!" % positions
		notification_label.add_theme_color_override("font_color", Color.RED)

	# Play sound
	_play_notification_sound(gained)

	# Animate: slide in, hold, fade out
	animation_tween = create_tween()

	# Start off-screen and transparent
	notification_label.position.x = 50
	notification_label.modulate.a = 0.0

	# Slide in and fade in
	animation_tween.parallel().tween_property(notification_label, "position:x", 0, SLIDE_DURATION).set_ease(Tween.EASE_OUT)
	animation_tween.parallel().tween_property(notification_label, "modulate:a", 1.0, SLIDE_DURATION)

	# Hold
	animation_tween.tween_interval(NOTIFICATION_DURATION)

	# Fade out
	animation_tween.tween_property(notification_label, "modulate:a", 0.0, FADE_DURATION)

## Generate and play a notification sound
func _play_notification_sound(gained: bool) -> void:
	var sample_rate = 44100
	var duration = 0.15
	var samples = int(sample_rate * duration)

	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false

	var data = PackedByteArray()
	data.resize(samples * 2)

	# Generate a simple tone
	var base_freq = 880.0 if gained else 440.0  # High pitch for gain, low for loss
	var freq_end = 1100.0 if gained else 330.0  # Pitch slides up for gain, down for loss

	for i in samples:
		var t = float(i) / sample_rate
		var progress = float(i) / samples

		# Frequency sweep
		var freq = lerp(base_freq, freq_end, progress)

		# Generate sine wave with envelope
		var envelope = 1.0 - progress  # Fade out
		var sample_value = sin(TAU * freq * t) * envelope * 0.3

		# Convert to 16-bit
		var sample_int = int(sample_value * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	audio.data = data
	audio_player.stream = audio
	audio_player.volume_db = -6.0
	audio_player.play()

## Reset position tracking (call at race start)
func reset() -> void:
	last_position = -1
	notification_label.modulate.a = 0.0
	if animation_tween and animation_tween.is_valid():
		animation_tween.kill()
