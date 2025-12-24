
# SurfaceManager.gd
class_name SurfaceManager
extends Node

var surface_data: Dictionary = {
	"road": SurfaceProperties.new(1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0),
	"grass": SurfaceProperties.new(0.7, 0.8, 0.8, 1.2, 0.6, 0.7, 0.9, 1.2),
	"deep_grass": SurfaceProperties.new(0.4, 0.6, 0.6, 1.5, 0.5, 0.6, 0.8, 1.3),
	"dirt": SurfaceProperties.new(0.8, 1.0, 0.7, 1.8, 0.7, 0.8, 0.9, 1.1),
	"sand": SurfaceProperties.new(0.5, 0.5, 0.7, 1.8, 0.5, 0.6, 0.7, 1.4)
}

var weather_modifier: float = 1.0

func set_weather_modifier(modifier: float) -> void:
	weather_modifier = modifier

func get_surface_properties(surface: String) -> SurfaceProperties:
	var props = surface_data.get(surface, surface_data["road"])
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
