
# SurfaceManager.gd
class_name SurfaceManager
extends Node

var surface_data: Dictionary = {}
var weather_modifier: float = 1.0
var current_weather: String = "clear"
var weather_data: Dictionary = {}

# Detailed weather modifiers
var weather_grip_mult: float = 1.0
var weather_brake_mult: float = 1.0
var weather_accel_mult: float = 1.0
var weather_drift_mult: float = 1.0
var weather_visibility: float = 1.0

signal weather_changed(weather_name: String, weather_config: Dictionary)

func _ready() -> void:
	_load_surfaces_from_config()
	_load_weather_from_config()

func _load_surfaces_from_config() -> void:
	surface_data.clear()
	for surface_name in ConfigManager.get_surface_names():
		var config = ConfigManager.get_surface(surface_name)
		surface_data[surface_name] = SurfaceProperties.new(
			config.get("speed", 1.0),
			config.get("friction", 1.0),
			config.get("acceleration", 1.0),
			config.get("drift", 1.0),
			config.get("grip", 1.0),
			config.get("brake", 1.0),
			config.get("rotation", 1.0),
			config.get("drag", 1.0)
		)

func _load_weather_from_config() -> void:
	# Load weather modifiers from surfaces config (already loaded by ConfigManager)
	if ConfigManager.surfaces.has("weather_modifiers"):
		weather_data = ConfigManager.surfaces["weather_modifiers"]

func reload_from_config() -> void:
	_load_surfaces_from_config()
	_load_weather_from_config()

## Set weather by name (from config)
func set_weather(weather_name: String) -> void:
	if not weather_data.has(weather_name):
		weather_name = "clear"

	current_weather = weather_name
	var config = weather_data.get(weather_name, {})

	weather_grip_mult = config.get("grip_multiplier", 1.0)
	weather_brake_mult = config.get("brake_multiplier", 1.0)
	weather_accel_mult = config.get("acceleration_multiplier", 1.0)
	weather_drift_mult = config.get("drift_multiplier", 1.0)
	weather_visibility = config.get("visibility", 1.0)

	# Also set the basic modifier for compatibility
	weather_modifier = weather_grip_mult

	weather_changed.emit(weather_name, config)

## Legacy method for basic weather modifier
func set_weather_modifier(modifier: float) -> void:
	weather_modifier = modifier
	weather_grip_mult = modifier
	weather_brake_mult = modifier
	weather_accel_mult = modifier

## Get current weather name
func get_current_weather() -> String:
	return current_weather

## Get weather visibility (0.0 to 1.0)
func get_visibility() -> float:
	return weather_visibility

## Get weather config data
func get_weather_config(weather_name: String = "") -> Dictionary:
	if weather_name.is_empty():
		weather_name = current_weather
	return weather_data.get(weather_name, {})

func get_surface_properties(surface: String) -> SurfaceProperties:
	var props = surface_data.get(surface, surface_data.get("road", SurfaceProperties.new()))

	# Apply weather modifiers if not clear/default
	if weather_grip_mult != 1.0 or weather_brake_mult != 1.0 or weather_accel_mult != 1.0 or weather_drift_mult != 1.0:
		var modified = SurfaceProperties.new(
			props.speed_multiplier,
			props.friction_multiplier * weather_grip_mult,
			props.acceleration_multiplier * weather_accel_mult,
			props.drift_multiplier * weather_drift_mult,
			props.grip_multiplier * weather_grip_mult,
			props.brake_multiplier * weather_brake_mult,
			props.rotation_multiplier,
			props.drag_multiplier
		)
		return modified
	return props
