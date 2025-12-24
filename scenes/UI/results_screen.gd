class_name ResultsScreen
extends CanvasLayer
## Displays race results when the race ends

@onready var results_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ResultsContainer
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var restart_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/RestartButton
@onready var quit_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/QuitButton

signal restart_requested()
signal quit_requested()

func _ready() -> void:
	hide()
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func show_results(results: Array, player_car: Car) -> void:
	# Clear previous results
	for child in results_container.get_children():
		child.queue_free()

	# Find player position
	var player_position = 1
	for result in results:
		if result["car"] == player_car:
			player_position = result["position"]
			break

	# Set title based on position
	match player_position:
		1:
			title_label.text = "YOU WON!"
			title_label.add_theme_color_override("font_color", Color.GOLD)
		2:
			title_label.text = "2nd Place!"
			title_label.add_theme_color_override("font_color", Color.SILVER)
		3:
			title_label.text = "3rd Place!"
			title_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))
		_:
			title_label.text = "Race Complete"
			title_label.add_theme_color_override("font_color", Color.WHITE)

	# Add result entries
	for result in results:
		var entry = _create_result_entry(result, player_car)
		results_container.add_child(entry)

	show()

func _create_result_entry(result: Dictionary, player_car: Car) -> HBoxContainer:
	var entry = HBoxContainer.new()
	entry.add_theme_constant_override("separation", 20)

	# Position
	var pos_label = Label.new()
	pos_label.text = "P%d" % result["position"]
	pos_label.custom_minimum_size = Vector2(50, 0)
	match result["position"]:
		1:
			pos_label.add_theme_color_override("font_color", Color.GOLD)
		2:
			pos_label.add_theme_color_override("font_color", Color.SILVER)
		3:
			pos_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))
	entry.add_child(pos_label)

	# Name
	var name_label = Label.new()
	var car_name = "YOU" if result["car"] == player_car else result["car"].name
	name_label.text = car_name
	name_label.custom_minimum_size = Vector2(100, 0)
	if result["car"] == player_car:
		name_label.add_theme_color_override("font_color", Color.YELLOW)
	entry.add_child(name_label)

	# Time
	var time_label = Label.new()
	time_label.text = "%.2fs" % result["total_time"]
	time_label.custom_minimum_size = Vector2(80, 0)
	entry.add_child(time_label)

	# Best Lap
	var best_lap_label = Label.new()
	best_lap_label.text = "Best: %.2fs" % result["best_lap"]
	entry.add_child(best_lap_label)

	return entry

func _on_restart_pressed() -> void:
	restart_requested.emit()
	hide()

func _on_quit_pressed() -> void:
	quit_requested.emit()
