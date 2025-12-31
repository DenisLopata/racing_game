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

# Procedural track options
var size_options = ["Small", "Medium", "Large"]
var turns_options = ["Few Turns", "Moderate", "Many Turns"]

# Current selections (indices)
var lap_index: int = 1  # Default: 3 laps
var opponent_index: int = 3  # Default: 7 opponents
var weather_index: int = 0  # Default: Clear
var difficulty_index: int = 1  # Default: Medium

# Procedural selections
var size_index: int = 1  # Default: Medium
var turns_index: int = 1  # Default: Moderate

# UI references
@onready var track_label: Label = $ScrollContainer/VBoxContainer/TrackRow/TrackLabel
@onready var locked_label: Label = $ScrollContainer/VBoxContainer/LockedLabel
@onready var lap_label: Label = $ScrollContainer/VBoxContainer/LapsRow/LapsValue
@onready var opponent_label: Label = $ScrollContainer/VBoxContainer/OpponentsRow/OpponentsValue
@onready var weather_label: Label = $ScrollContainer/VBoxContainer/WeatherRow/WeatherValue
@onready var difficulty_label: Label = $ScrollContainer/VBoxContainer/DifficultyRow/DifficultyValue
@onready var start_button: Button = $ScrollContainer/VBoxContainer/StartButton

# Procedural UI references
@onready var procedural_options: VBoxContainer = $ScrollContainer/VBoxContainer/ProceduralOptions
@onready var seed_input: LineEdit = $ScrollContainer/VBoxContainer/ProceduralOptions/SeedRow/SeedInput
@onready var size_label: Label = $ScrollContainer/VBoxContainer/ProceduralOptions/SizeRow/SizeValue
@onready var turns_label: Label = $ScrollContainer/VBoxContainer/ProceduralOptions/TurnsRow/TurnsValue

# Saved tracks popup references
@onready var saved_tracks_popup: Panel = $SavedTracksPopup
@onready var track_list: VBoxContainer = $SavedTracksPopup/VBoxContainer/ScrollContainer/TrackList
@onready var no_tracks_label: Label = $SavedTracksPopup/VBoxContainer/NoTracksLabel

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

	# Procedural options visibility
	var is_procedural = tracks[current_track_index].get("is_procedural", false)
	procedural_options.visible = is_procedural

	# Procedural labels
	if is_procedural:
		size_label.text = size_options[size_index]
		turns_label.text = turns_options[turns_index]

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

	# Handle procedural track settings
	var is_procedural = tracks[current_track_index].get("is_procedural", false)
	GameSettings.is_procedural_track = is_procedural

	if is_procedural:
		# Parse seed: empty = random, number = use it, string = hash it
		var seed_text = seed_input.text.strip_edges()
		if seed_text.is_empty():
			GameSettings.procedural_seed = 0  # Will use random
		elif seed_text.is_valid_int():
			GameSettings.procedural_seed = seed_text.to_int()
		else:
			GameSettings.procedural_seed = seed_text.hash()

		GameSettings.procedural_size = size_index
		GameSettings.procedural_difficulty = turns_index

	# Load the race scene
	var scene_path = tracks[current_track_index]["scene"]
	if scene_path != "":
		get_tree().change_scene_to_file(scene_path)

# Procedural options handlers
func _on_random_seed_pressed() -> void:
	seed_input.text = str(randi())

func _on_size_prev_pressed() -> void:
	size_index = (size_index - 1 + size_options.size()) % size_options.size()
	_update_all_labels()

func _on_size_next_pressed() -> void:
	size_index = (size_index + 1) % size_options.size()
	_update_all_labels()

func _on_turns_prev_pressed() -> void:
	turns_index = (turns_index - 1 + turns_options.size()) % turns_options.size()
	_update_all_labels()

func _on_turns_next_pressed() -> void:
	turns_index = (turns_index + 1) % turns_options.size()
	_update_all_labels()

# Saved tracks popup handlers
func _on_load_saved_pressed() -> void:
	_populate_saved_tracks()
	saved_tracks_popup.visible = true

func _on_saved_tracks_close_pressed() -> void:
	saved_tracks_popup.visible = false

func _populate_saved_tracks() -> void:
	# Clear existing entries
	for child in track_list.get_children():
		child.queue_free()

	var saved = GameSettings.get_saved_tracks()

	if saved.is_empty():
		no_tracks_label.visible = true
		return

	no_tracks_label.visible = false

	for i in saved.size():
		var track_data = saved[i]
		var entry = _create_saved_track_entry(i, track_data)
		track_list.add_child(entry)

func _create_saved_track_entry(index: int, track_data: Dictionary) -> HBoxContainer:
	var entry = HBoxContainer.new()
	entry.add_theme_constant_override("separation", 10)

	# Track name label
	var name_label = Label.new()
	name_label.text = track_data.get("name", "Track")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_child(name_label)

	# Load button
	var load_btn = Button.new()
	load_btn.text = "Load"
	load_btn.custom_minimum_size = Vector2(60, 25)
	load_btn.pressed.connect(_on_load_track.bind(index))
	entry.add_child(load_btn)

	# Delete button
	var delete_btn = Button.new()
	delete_btn.text = "Del"
	delete_btn.custom_minimum_size = Vector2(40, 25)
	delete_btn.pressed.connect(_on_delete_track.bind(index))
	entry.add_child(delete_btn)

	return entry

func _on_load_track(index: int) -> void:
	if GameSettings.load_saved_track(index):
		# Update UI with loaded settings
		seed_input.text = str(GameSettings.procedural_seed)
		size_index = GameSettings.procedural_size
		turns_index = GameSettings.procedural_difficulty
		_update_all_labels()
		saved_tracks_popup.visible = false

func _on_delete_track(index: int) -> void:
	GameSettings.delete_saved_track(index)
	_populate_saved_tracks()
