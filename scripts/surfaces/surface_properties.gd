class_name SurfaceProperties

var speed_multiplier: float
var friction_multiplier: float
var acceleration_multiplier: float
var drift_multiplier: float
var grip_multiplier: float
var brake_multiplier: float
var rotation_multiplier: float
var drag_multiplier: float

func _init(
	speed := 1.0,
	friction := 1.0,
	acceleration := 1.0,
	drift := 1.0,
	grip := 1.0,
	brake := 1.0,
	rotation := 1.0,
	drag := 1.0
) -> void:
	speed_multiplier = speed
	friction_multiplier = friction
	acceleration_multiplier = acceleration
	drift_multiplier = drift
	grip_multiplier = grip
	brake_multiplier = brake
	rotation_multiplier = rotation
	drag_multiplier = drag
