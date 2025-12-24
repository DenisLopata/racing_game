extends Control
## Main Menu - Home screen with Start, Options, Quit buttons

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/race_setup.tscn")

func _on_options_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/options_menu.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
