extends Control
## Race Setup - Track selection and race settings

# Track data (loaded from ConfigManager)
var tracks: Array = []
var current_track_index: int = 0

# Settings options
var lap_options = [1, 3, 5, 10]
var opponent_options = [0, 3, 5, 7]
var weather_options: Array = []
var difficulty_options = ["Easy", "Medium", "Hard", "Expert"]

# Current selections (indices)
var lap_index: int = 1  # Default: 3 laps
var opponent_index: int = 3  # Default: 7 opponents
var weather_index: int = 0  # Default: Clear
var difficulty_index: int = 1  # Default: Medium

# UI references
@onready var track_label: Label = $VBoxContainer/TrackRow/TrackLabel
@onready var locked_label: Label = $VBoxContainer/LockedLabel
@onready var lap_label: Label = $VBoxContainer/LapsRow/LapsValue
@onready var opponent_label: Label = $VBoxContainer/OpponentsRow/OpponentsValue
@onready var weather_label: Label = $VBoxContainer/WeatherRow/WeatherValue
@onready var difficulty_label: Label = $VBoxContainer/DifficultyRow/DifficultyValue
@onready var start_button: Button = $VBoxContainer/StartButton

func _ready() -> void:
	_load_from_config()
	_update_all_labels()

func _load_from_config() -> void:
	# Load tracks from config
	tracks = ConfigManager.get_all_tracks()

	# Load weather options from config
	weather_options.clear()
	for weather_type in ConfigManager.get_weather_types():
		weather_options.append(weather_type.capitalize())

func _update_all_labels() -> void:
	# Track
	track_label.text = tracks[current_track_index]["name"]
	locked_label.visible = tracks[current_track_index]["locked"]
	start_button.disabled = tracks[current_track_index]["locked"]

	# Settings
	lap_label.text = str(lap_options[lap_index])
	opponent_label.text = str(opponent_options[opponent_index])
	weather_label.text = weather_options[weather_index]
	difficulty_label.text = difficulty_options[difficulty_index]

# Track navigation
func _on_track_prev_pressed() -> void:
	current_track_index = (current_track_index - 1 + tracks.size()) % tracks.size()
	_update_all_labels()

func _on_track_next_pressed() -> void:
	current_track_index = (current_track_index + 1) % tracks.size()
	_update_all_labels()

# Laps navigation
func _on_laps_prev_pressed() -> void:
	lap_index = (lap_index - 1 + lap_options.size()) % lap_options.size()
	_update_all_labels()

func _on_laps_next_pressed() -> void:
	lap_index = (lap_index + 1) % lap_options.size()
	_update_all_labels()

# Opponents navigation
func _on_opponents_prev_pressed() -> void:
	opponent_index = (opponent_index - 1 + opponent_options.size()) % opponent_options.size()
	_update_all_labels()

func _on_opponents_next_pressed() -> void:
	opponent_index = (opponent_index + 1) % opponent_options.size()
	_update_all_labels()

# Weather navigation
func _on_weather_prev_pressed() -> void:
	weather_index = (weather_index - 1 + weather_options.size()) % weather_options.size()
	_update_all_labels()

func _on_weather_next_pressed() -> void:
	weather_index = (weather_index + 1) % weather_options.size()
	_update_all_labels()

# Difficulty navigation
func _on_difficulty_prev_pressed() -> void:
	difficulty_index = (difficulty_index - 1 + difficulty_options.size()) % difficulty_options.size()
	_update_all_labels()

func _on_difficulty_next_pressed() -> void:
	difficulty_index = (difficulty_index + 1) % difficulty_options.size()
	_update_all_labels()

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/main_menu.tscn")

func _on_start_button_pressed() -> void:
	# Save settings to GameSettings
	GameSettings.selected_track = tracks[current_track_index]["id"]
	GameSettings.lap_count = lap_options[lap_index]
	GameSettings.opponent_count = opponent_options[opponent_index]
	GameSettings.weather = weather_options[weather_index].to_lower()
	GameSettings.ai_difficulty = difficulty_options[difficulty_index].to_lower()

	# Load the race scene
	var scene_path = tracks[current_track_index]["scene"]
	if scene_path != "":
		get_tree().change_scene_to_file(scene_path)
