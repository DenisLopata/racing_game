class_name WeightTransfer
extends RefCounted
## Simulates weight transfer during acceleration, braking, and turning
## Affects grip distribution between front and rear axles

# Vehicle properties
var wheelbase: float = 2.5             # Distance between axles (meters, scaled)
var center_of_gravity_height: float = 0.5  # CoG height (meters, scaled)
var base_weight_distribution: float = 0.5  # 0.5 = 50/50, <0.5 = front heavy

# Transfer rates (how quickly weight shifts)
var longitudinal_transfer_rate: float = 8.0  # Accel/brake transfer speed
var lateral_transfer_rate: float = 6.0       # Cornering transfer speed

# Current state
var front_load: float = 0.5            # Current front axle load (0-1)
var rear_load: float = 0.5             # Current rear axle load (0-1)
var left_load: float = 0.5             # Current left side load (0-1)
var right_load: float = 0.5            # Current right side load (0-1)

# Smoothed values for visual feedback
var _target_front_load: float = 0.5
var _target_lateral_load: float = 0.5  # 0.5 = centered, <0.5 = left, >0.5 = right

## Update weight distribution based on car state
## acceleration: positive = accelerating, negative = braking
## lateral_g: lateral acceleration (positive = turning right)
## delta: frame time
func update(acceleration: float, lateral_g: float, delta: float) -> void:
	# Longitudinal weight transfer (front/rear)
	# Braking shifts weight forward, acceleration shifts weight backward
	var longitudinal_shift = -acceleration * center_of_gravity_height / wheelbase
	longitudinal_shift = clamp(longitudinal_shift, -0.3, 0.3)  # Max 30% transfer

	_target_front_load = base_weight_distribution + longitudinal_shift

	# Lateral weight transfer (left/right)
	# Turning right shifts weight left (outside of turn)
	var lateral_shift = lateral_g * center_of_gravity_height / wheelbase
	lateral_shift = clamp(lateral_shift, -0.25, 0.25)  # Max 25% transfer

	_target_lateral_load = 0.5 - lateral_shift

	# Smooth the actual values
	front_load = lerp(front_load, _target_front_load, delta * longitudinal_transfer_rate)
	rear_load = 1.0 - front_load

	var lateral_center = lerp(left_load, _target_lateral_load, delta * lateral_transfer_rate)
	left_load = lateral_center
	right_load = 1.0 - lateral_center

## Get grip multiplier for front axle
func get_front_grip_multiplier() -> float:
	# More weight = more grip (with diminishing returns)
	return _load_to_grip(front_load * 2.0)  # *2 because base is 0.5

## Get grip multiplier for rear axle
func get_rear_grip_multiplier() -> float:
	return _load_to_grip(rear_load * 2.0)

## Get grip multiplier for left side
func get_left_grip_multiplier() -> float:
	return _load_to_grip(left_load * 2.0)

## Get grip multiplier for right side
func get_right_grip_multiplier() -> float:
	return _load_to_grip(right_load * 2.0)

## Convert load factor to grip multiplier (diminishing returns)
func _load_to_grip(load_factor: float) -> float:
	# Square root gives diminishing returns
	# load 1.0 -> grip 1.0
	# load 1.5 -> grip 1.22
	# load 0.5 -> grip 0.71
	return sqrt(clamp(load_factor, 0.2, 2.0))

## Get combined grip for a wheel position
## position: "front_left", "front_right", "rear_left", "rear_right"
func get_wheel_grip(position: String) -> float:
	var longitudinal: float
	var lateral: float

	match position:
		"front_left":
			longitudinal = get_front_grip_multiplier()
			lateral = get_left_grip_multiplier()
		"front_right":
			longitudinal = get_front_grip_multiplier()
			lateral = get_right_grip_multiplier()
		"rear_left":
			longitudinal = get_rear_grip_multiplier()
			lateral = get_left_grip_multiplier()
		"rear_right":
			longitudinal = get_rear_grip_multiplier()
			lateral = get_right_grip_multiplier()
		_:
			return 1.0

	# Combine (geometric mean)
	return sqrt(longitudinal * lateral)

## Get average front grip
func get_front_grip() -> float:
	return get_front_grip_multiplier()

## Get average rear grip
func get_rear_grip() -> float:
	return get_rear_grip_multiplier()

## Get current lateral weight transfer (-1 = full left, 0 = centered, 1 = full right)
func get_current_lateral() -> float:
	return (left_load - 0.5) * 2.0  # Convert 0-1 range to -1 to 1

## Check if car is likely to understeer (front losing grip)
func is_understeering() -> bool:
	return front_load < 0.4

## Check if car is likely to oversteer (rear losing grip)
func is_oversteering() -> bool:
	return rear_load < 0.4

## Configure for different weight distributions
func configure(distribution: String) -> void:
	match distribution:
		"front_heavy":  # FWD typical
			base_weight_distribution = 0.58
		"rear_heavy":   # RWD sports car
			base_weight_distribution = 0.45
		"balanced":     # 50/50
			base_weight_distribution = 0.50
		"mid_engine":   # Mid-engine sports
			base_weight_distribution = 0.42

## Get debug info
func get_debug_info() -> Dictionary:
	return {
		"front_load": front_load,
		"rear_load": rear_load,
		"left_load": left_load,
		"right_load": right_load,
		"understeer_risk": is_understeering(),
		"oversteer_risk": is_oversteering()
	}
