extends Node
## ConfigManager - Centralized configuration system with hot-reload support
## Loads all game configuration from JSON files in res://config/

signal config_reloaded(config_name: String)

## Loaded configuration data
var cars: Dictionary = {}
var ai_difficulty: Dictionary = {}
var surfaces: Dictionary = {}
var weather: Dictionary = {}
var tracks: Dictionary = {}
var game: Dictionary = {}
var parts: Dictionary = {}

const CONFIG_PATH = "res://config/"

func _ready() -> void:
	load_all_configs()

## Load all configuration files
func load_all_configs() -> void:
	cars = _load_json("cars.json")
	ai_difficulty = _load_json("ai_difficulty.json")
	surfaces = _load_json("surfaces.json")
	weather = _load_json("weather.json")
	tracks = _load_json("tracks.json")
	game = _load_json("game.json")
	parts = _load_json("parts.json")

## Reload a specific config file
func reload_config(config_name: String) -> void:
	match config_name:
		"cars":
			cars = _load_json("cars.json")
		"ai_difficulty":
			ai_difficulty = _load_json("ai_difficulty.json")
		"surfaces":
			surfaces = _load_json("surfaces.json")
		"weather":
			weather = _load_json("weather.json")
		"tracks":
			tracks = _load_json("tracks.json")
		"game":
			game = _load_json("game.json")
		"parts":
			parts = _load_json("parts.json")
	config_reloaded.emit(config_name)

## Reload all configs (hot-reload)
func reload_all() -> void:
	load_all_configs()
	config_reloaded.emit("all")
	print("[ConfigManager] All configs reloaded")

## Load a JSON file and return as Dictionary
func _load_json(filename: String) -> Dictionary:
	var path = CONFIG_PATH + filename
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var json = JSON.parse_string(content)
		if json != null:
			return json
		else:
			push_error("[ConfigManager] Failed to parse JSON: %s" % path)
	else:
		push_error("[ConfigManager] Failed to open file: %s" % path)
	return {}

# =============================================================================
# Car Config Helpers
# =============================================================================

## Get car tuning preset by mode (arcade, realistic, hybrid)
func get_car_preset(mode: String) -> Dictionary:
	return cars.get("presets", {}).get(mode, {})

## Get drivetrain modifier (FWD, RWD, AWD)
func get_drivetrain_modifier(drivetrain: String) -> Dictionary:
	return cars.get("drivetrain_modifiers", {}).get(drivetrain, {"steering_mult": 1.0, "lateral_grip": 0.2})

## Get car physics constants
func get_car_physics() -> Dictionary:
	return cars.get("physics", {})

# =============================================================================
# AI Config Helpers
# =============================================================================

## Get AI difficulty settings by level
func get_ai_difficulty_settings(level: String) -> Dictionary:
	return ai_difficulty.get(level, ai_difficulty.get("medium", {}))

## Get AI constants (stuck detection, lookahead, etc.)
func get_ai_constants() -> Dictionary:
	return ai_difficulty.get("constants", {})

# =============================================================================
# Surface Config Helpers
# =============================================================================

## Get surface properties by name
func get_surface(name: String) -> Dictionary:
	return surfaces.get(name, surfaces.get("road", {}))

## Get all surface names
func get_surface_names() -> Array:
	return surfaces.keys()

# =============================================================================
# Weather Config Helpers
# =============================================================================

## Get weather settings by name
func get_weather_settings(name: String) -> Dictionary:
	return weather.get(name, {"grip_modifier": 1.0, "visual_effect": null})

## Get weather grip modifier
func get_weather_grip(name: String) -> float:
	return weather.get(name, {}).get("grip_modifier", 1.0)

## Get all weather types
func get_weather_types() -> Array:
	return weather.keys()

# =============================================================================
# Track Config Helpers
# =============================================================================

## Get track data by ID
func get_track(id: String) -> Dictionary:
	return tracks.get(id, {})

## Get all tracks as array (for UI)
func get_all_tracks() -> Array:
	var result = []
	for id in tracks.keys():
		var track = tracks[id].duplicate()
		track["id"] = id
		result.append(track)
	return result

## Get unlocked tracks only
func get_unlocked_tracks() -> Array:
	return get_all_tracks().filter(func(t): return not t.get("locked", false))

# =============================================================================
# Game Config Helpers
# =============================================================================

## Get default game settings
func get_defaults() -> Dictionary:
	return game.get("defaults", {})

## Get audio settings
func get_audio_settings() -> Dictionary:
	return game.get("audio", {})

## Get camera settings
func get_camera_settings() -> Dictionary:
	return game.get("camera", {})

## Get visual settings
func get_visual_settings() -> Dictionary:
	return game.get("visuals", {})

## Get AI colors array
func get_ai_colors() -> Array:
	return game.get("ai_colors", [])

## Get drift physics settings
func get_drift_settings() -> Dictionary:
	return game.get("drift", {})

## Get race settings
func get_race_settings() -> Dictionary:
	return game.get("race", {})

# =============================================================================
# Utility
# =============================================================================

## Convert color array [r, g, b] or [r, g, b, a] to Color
func array_to_color(arr: Array) -> Color:
	if arr.size() >= 4:
		return Color(arr[0], arr[1], arr[2], arr[3])
	elif arr.size() >= 3:
		return Color(arr[0], arr[1], arr[2])
	return Color.WHITE

# =============================================================================
# Parts Config Helpers
# =============================================================================

## Get all parts in a category (engines, tires, spoilers, brakes, suspensions)
func get_parts_category(category: String) -> Dictionary:
	return parts.get(category, {})

## Get a specific part by category and id
func get_part(category: String, part_id: String) -> Dictionary:
	return parts.get(category, {}).get(part_id, {})

## Get all engines
func get_engines() -> Dictionary:
	return parts.get("engines", {})

## Get all tires
func get_tires() -> Dictionary:
	return parts.get("tires", {})

## Get all spoilers
func get_spoilers() -> Dictionary:
	return parts.get("spoilers", {})

## Get all brakes
func get_brakes() -> Dictionary:
	return parts.get("brakes", {})

## Get all suspensions
func get_suspensions() -> Dictionary:
	return parts.get("suspensions", {})

## Get race reward settings
func get_race_rewards() -> Dictionary:
	return parts.get("rewards", {})

## Get position rewards mapping
func get_position_rewards() -> Dictionary:
	return parts.get("rewards", {}).get("position_rewards", {"1": 500, "2": 300, "3": 200, "4": 100, "default": 50})

## Get all part categories
func get_part_categories() -> Array:
	return ["engines", "tires", "spoilers", "brakes", "suspensions"]
