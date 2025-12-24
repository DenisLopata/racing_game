class_name CountdownOverlay
extends CanvasLayer
## Displays the 3-2-1-GO countdown before race starts

@onready var countdown_label: Label = $CenterContainer/CountdownLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_showing: bool = false

func _ready() -> void:
	# Connect to RaceManager signals
	RaceManager.countdown_tick.connect(_on_countdown_tick)
	RaceManager.race_started.connect(_on_race_started)
	RaceManager.race_state_changed.connect(_on_race_state_changed)

	# Initially hidden
	hide()

func _on_race_state_changed(new_state: RaceManager.RaceState) -> void:
	if new_state == RaceManager.RaceState.COUNTDOWN:
		show()
		is_showing = true
	elif new_state == RaceManager.RaceState.RACING:
		# Hide after "GO!" animation completes
		pass

func _on_countdown_tick(seconds: int) -> void:
	if seconds > 0:
		countdown_label.text = str(seconds)
		countdown_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		countdown_label.text = "GO!"
		countdown_label.add_theme_color_override("font_color", Color.GREEN)

	# Play pop animation
	_play_pop_animation()

func _on_race_started() -> void:
	# Hide after a short delay
	await get_tree().create_timer(0.5).timeout
	hide()
	is_showing = false

func _play_pop_animation() -> void:
	# Simple scale animation
	var tween = create_tween()
	countdown_label.scale = Vector2(0.5, 0.5)
	tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
