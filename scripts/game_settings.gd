extends Node
## Global game settings singleton
## Stores audio settings (persisted) and race settings (per-session)

# Audio settings (saved to disk)
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0

# Race settings (set by race_setup, read by main.gd)
var selected_track: String = "sunset_circuit"
var lap_count: int = 3
var opponent_count: int = 7
var weather: String = "clear"
var ai_difficulty: String = "medium"

const SETTINGS_PATH = "user://settings.cfg"

func _ready() -> void:
	load_settings()

## Save audio settings to disk
func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save(SETTINGS_PATH)
	_apply_audio_settings()

## Load audio settings from disk
func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		master_volume = config.get_value("audio", "master_volume", 1.0)
		music_volume = config.get_value("audio", "music_volume", 0.8)
		sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
	_apply_audio_settings()

## Apply audio settings to the audio buses
func _apply_audio_settings() -> void:
	# Master bus
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(master_volume))

	# Music bus (if exists)
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(music_volume))

	# SFX bus (if exists)
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_volume))

## Get weather grip multiplier
func get_weather_grip_multiplier() -> float:
	match weather:
		"clear":
			return 1.0
		"rain":
			return 0.7
		"fog":
			return 0.9
	return 1.0
