extends Control
## Options Menu - Audio volume settings

@onready var master_slider: HSlider = $VBoxContainer/MasterRow/MasterSlider
@onready var music_slider: HSlider = $VBoxContainer/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $VBoxContainer/SFXRow/SFXSlider

@onready var master_value: Label = $VBoxContainer/MasterRow/MasterValue
@onready var music_value: Label = $VBoxContainer/MusicRow/MusicValue
@onready var sfx_value: Label = $VBoxContainer/SFXRow/SFXValue

func _ready() -> void:
	# Load current values from GameSettings
	master_slider.value = GameSettings.master_volume * 100
	music_slider.value = GameSettings.music_volume * 100
	sfx_slider.value = GameSettings.sfx_volume * 100
	_update_labels()

func _update_labels() -> void:
	master_value.text = "%d%%" % int(master_slider.value)
	music_value.text = "%d%%" % int(music_slider.value)
	sfx_value.text = "%d%%" % int(sfx_slider.value)

func _on_master_slider_value_changed(value: float) -> void:
	GameSettings.master_volume = value / 100.0
	GameSettings._apply_audio_settings()  # Apply immediately so user can hear
	_update_labels()

func _on_music_slider_value_changed(value: float) -> void:
	GameSettings.music_volume = value / 100.0
	GameSettings._apply_audio_settings()  # Apply immediately so user can hear
	_update_labels()

func _on_sfx_slider_value_changed(value: float) -> void:
	GameSettings.sfx_volume = value / 100.0
	GameSettings._apply_audio_settings()  # Apply immediately so user can hear
	_update_labels()

func _on_save_button_pressed() -> void:
	GameSettings.save_settings()
	get_tree().change_scene_to_file("res://scenes/UI/main_menu.tscn")

func _on_back_button_pressed() -> void:
	# Revert to saved settings
	GameSettings.load_settings()
	get_tree().change_scene_to_file("res://scenes/UI/main_menu.tscn")
