class_name DriftManager
extends Node

var smoothing: float = 5.0
var decay_speed: float = 2.0
var max_ratio: float = 1.5   # How much lateral vs forward ratio counts as "full drift"

var current_drift: float = 0.0
var surface_drift_multiplier: float = 1.0


var drift_min_speed: float = 100.0
var steering_influence: float = 5.0

func update_drift(delta: float, velocity: Vector2, forward_dir: Vector2, steering: float) -> float:
	var speed = velocity.length()
	
	# Ignore drift at low speeds
	if speed < drift_min_speed:
		current_drift = lerp(current_drift, 0.0, delta * decay_speed)
		return current_drift
	
	# Decompose velocity
	var right = forward_dir.rotated(-PI/2)
	var forward_speed = abs(velocity.dot(forward_dir))
	var lateral_speed = abs(velocity.dot(right))

	# Base drift from lateral vs forward
	var ratio = lateral_speed / max(forward_speed, 1.0)
	
	# Add steering influence (exaggerates drift at high steering angles)
	var steering_factor = abs(steering) * steering_influence
	
	var target_drift = clamp((ratio + steering_factor) / max_ratio, 0.0, 1.0)
	target_drift *= surface_drift_multiplier
	
	# Smooth persistence (drift lingers a bit)
	current_drift = lerp(current_drift, target_drift, delta * smoothing)
	
	return current_drift

#func update_drift(delta: float, velocity: Vector2, forward_dir: Vector2) -> float:
	#if velocity.length() < 10.0:
		#current_drift = lerp(current_drift, 0.0, delta * decay_speed)
		#return current_drift
#
	## Decompose velocity into forward (longitudinal) and lateral components
	#var right = forward_dir.rotated(-PI/2)
	#var forward_speed = abs(velocity.dot(forward_dir))
	#var lateral_speed = abs(velocity.dot(right))
#
	## Drift is ratio of lateral vs forward motion
	#var ratio = 0.0
	#if forward_speed > 1.0:
		#ratio = lateral_speed / forward_speed
#
	#var target_drift = clamp(ratio / max_ratio, 0.0, 1.0)
	#target_drift *= surface_drift_multiplier
#
	## Smooth drift value
	#current_drift = lerp(current_drift, target_drift, delta * smoothing)
	#return current_drift
