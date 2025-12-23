
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

func get_surface_properties(surface: String) -> SurfaceProperties:
	return surface_data.get(surface, surface_data["road"])
