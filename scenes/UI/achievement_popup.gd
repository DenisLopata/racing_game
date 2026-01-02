class_name AchievementPopup
extends CanvasLayer
## Shows a popup notification when an achievement is unlocked

const DISPLAY_DURATION: float = 3.0
const SLIDE_DURATION: float = 0.3

var panel: PanelContainer
var tween: Tween

func _init() -> void:
	layer = 100  # Always on top

func _ready() -> void:
	_build_ui()

	# Connect to AchievementManager
	if AchievementManager:
		AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "AchievementPanel"

	# Position at top center, starts off-screen
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -150
	panel.offset_right = 150
	panel.offset_top = -100  # Start above screen
	panel.offset_bottom = 0

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	# "Achievement Unlocked" header
	var header = Label.new()
	header.name = "Header"
	header.text = "ACHIEVEMENT UNLOCKED"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(header)

	# Achievement name
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = "Achievement Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)

	# Achievement description
	var desc_label = Label.new()
	desc_label.name = "DescLabel"
	desc_label.text = "Achievement description"
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(desc_label)

	add_child(panel)
	panel.visible = false

func _on_achievement_unlocked(_achievement_id: String, achievement: Dictionary) -> void:
	_show_popup(achievement)

func _show_popup(achievement: Dictionary) -> void:
	# Update text
	var name_label = panel.get_node("MarginContainer/VBoxContainer/NameLabel")
	var desc_label = panel.get_node("MarginContainer/VBoxContainer/DescLabel")

	if name_label:
		name_label.text = achievement.get("name", "Unknown")
	if desc_label:
		desc_label.text = achievement.get("description", "")

	# Cancel any existing animation
	if tween and tween.is_valid():
		tween.kill()

	# Reset position and show
	panel.offset_top = -100
	panel.visible = true

	# Animate
	tween = create_tween()

	# Slide down
	tween.tween_property(panel, "offset_top", 20, SLIDE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Wait
	tween.tween_interval(DISPLAY_DURATION)

	# Slide up
	tween.tween_property(panel, "offset_top", -100, SLIDE_DURATION).set_ease(Tween.EASE_IN)

	# Hide
	tween.tween_callback(func(): panel.visible = false)

	# Play sound
	_play_unlock_sound()

func _play_unlock_sound() -> void:
	var audio = AudioStreamPlayer.new()
	audio.bus = "SFX"
	add_child(audio)

	# Generate a cheerful unlock sound
	var sample_rate = 44100
	var duration = 0.4
	var samples = int(sample_rate * duration)

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false

	var data = PackedByteArray()
	data.resize(samples * 2)

	for i in samples:
		var t = float(i) / sample_rate
		var progress = float(i) / samples

		# Rising arpeggio effect
		var freq1 = 523.25  # C5
		var freq2 = 659.25  # E5
		var freq3 = 783.99  # G5

		var note_progress = progress * 3.0
		var freq: float
		if note_progress < 1.0:
			freq = freq1
		elif note_progress < 2.0:
			freq = freq2
		else:
			freq = freq3

		var envelope = 1.0 - progress
		var sample_value = sin(TAU * freq * t) * envelope * 0.3

		var sample_int = int(sample_value * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	stream.data = data
	audio.stream = stream
	audio.volume_db = -3.0
	audio.play()

	# Clean up after playing
	audio.finished.connect(func(): audio.queue_free())
