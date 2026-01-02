extends Node
## Global game settings singleton
## Stores audio settings (persisted) and race settings (per-session)

# Audio settings (saved to disk)
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0

# Visual settings (saved to disk)
var screen_shake_enabled: bool = true

# Race settings (set by race_setup, read by main.gd)
var selected_track: String = "sunset_circuit"
var lap_count: int = 3
var opponent_count: int = 7
var weather: String = "clear"
var ai_difficulty: String = "medium"
var is_time_attack: bool = false

# Procedural track settings (per-session)
var is_procedural_track: bool = false
var procedural_seed: int = 0  # 0 = random
var procedural_size: int = 1  # 0=Small, 1=Medium, 2=Large
var procedural_difficulty: int = 1  # 0=Few turns, 1=Moderate, 2=Many turns

# Saved favorite tracks
var saved_tracks: Array = []
const SAVED_TRACKS_PATH = "user://saved_tracks.json"

const SETTINGS_PATH = "user://settings.cfg"

func _ready() -> void:
	load_settings()

## Save settings to disk
func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("visual", "screen_shake_enabled", screen_shake_enabled)
	config.save(SETTINGS_PATH)
	_apply_audio_settings()

## Load settings from disk
func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		master_volume = config.get_value("audio", "master_volume", 1.0)
		music_volume = config.get_value("audio", "music_volume", 0.8)
		sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
		screen_shake_enabled = config.get_value("visual", "screen_shake_enabled", true)
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

# =============================================================================
# Procedural Track Favorites
# =============================================================================

## Save current procedural track as a favorite
func save_favorite_track(track_name: String) -> void:
	if not is_procedural_track:
		return

	saved_tracks.append({
		"name": track_name,
		"seed": procedural_seed,
		"size": procedural_size,
		"difficulty": procedural_difficulty,
		"created": Time.get_datetime_string_from_system()
	})
	_save_tracks_to_file()

## Load saved tracks from disk
func load_saved_tracks() -> void:
	var file = FileAccess.open(SAVED_TRACKS_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var json = JSON.parse_string(content)
		if json != null and json is Array:
			saved_tracks = json

## Save tracks to disk
func _save_tracks_to_file() -> void:
	var file = FileAccess.open(SAVED_TRACKS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(saved_tracks, "\t"))
		file.close()

## Get list of saved tracks
func get_saved_tracks() -> Array:
	load_saved_tracks()
	return saved_tracks

## Load a saved track settings
func load_saved_track(index: int) -> bool:
	if index < 0 or index >= saved_tracks.size():
		return false

	var track = saved_tracks[index]
	is_procedural_track = true
	procedural_seed = track.get("seed", 0)
	procedural_size = track.get("size", 1)
	procedural_difficulty = track.get("difficulty", 1)
	return true

## Delete a saved track
func delete_saved_track(index: int) -> void:
	if index >= 0 and index < saved_tracks.size():
		saved_tracks.remove_at(index)
		_save_tracks_to_file()
