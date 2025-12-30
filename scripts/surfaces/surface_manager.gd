
# SurfaceManager.gd
class_name SurfaceManager
extends Node

var surface_data: Dictionary = {}
var weather_modifier: float = 1.0

func _ready() -> void:
	_load_surfaces_from_config()

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

func reload_from_config() -> void:
	_load_surfaces_from_config()

func set_weather_modifier(modifier: float) -> void:
	weather_modifier = modifier

func get_surface_properties(surface: String) -> SurfaceProperties:
	var props = surface_data.get(surface, surface_data.get("road", SurfaceProperties.new()))
	if weather_modifier != 1.0:
		# Apply weather modifier to grip-related properties
		var modified = SurfaceProperties.new(
			props.speed_multiplier,
			props.friction_multiplier * weather_modifier,
			props.acceleration_multiplier * weather_modifier,
			props.drift_multiplier,
			props.grip_multiplier * weather_modifier,
			props.brake_multiplier * weather_modifier,
			props.rotation_multiplier,
			props.drag_multiplier
		)
		return modified
	return props
