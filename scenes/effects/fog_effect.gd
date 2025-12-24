extends Node2D
## Fog visual effect - follows camera

var camera: Camera2D

func _ready() -> void:
	# Find the active camera
	await get_tree().process_frame
	camera = get_viewport().get_camera_2d()

func _process(_delta: float) -> void:
	if camera:
		global_position = camera.global_position
