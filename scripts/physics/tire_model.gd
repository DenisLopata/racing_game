class_name TireModel
extends RefCounted
## Simplified Pacejka-inspired tire model for arcade racing
## Calculates grip based on slip angle and load

# Tire parameters (can be tuned per tire type)
var grip_coefficient: float = 1.0      # Base grip multiplier
var peak_slip_angle: float = 8.0       # Degrees at which grip peaks
var falloff_sharpness: float = 0.8     # How quickly grip falls off after peak
var load_sensitivity: float = 0.7      # How much load affects grip (0-1)

# Current state
var slip_angle: float = 0.0            # Current slip angle in degrees
var grip_force: float = 0.0            # Current grip output (0-1)
var is_sliding: bool = false           # Whether tire is past peak grip

## Calculate grip based on slip angle using simplified Pacejka curve
## Returns normalized grip force (0-1)
func calculate_grip(slip_angle_deg: float, load_factor: float = 1.0) -> float:
	slip_angle = abs(slip_angle_deg)

	# Simplified Pacejka-like curve: sin(atan(B*x)) * D
	# Where x is slip angle, B controls peak location, D is peak value
	var B = PI / (2.0 * peak_slip_angle)  # Shape factor
	var x = slip_angle

	# Calculate base grip from slip curve
	var base_grip: float
	if slip_angle < 0.1:
		# Very low slip - linear region
		base_grip = slip_angle / peak_slip_angle
	elif slip_angle <= peak_slip_angle:
		# Building grip region
		base_grip = sin(atan(B * x))
	else:
		# Past peak - grip falls off
		var over_peak = slip_angle - peak_slip_angle
		var peak_grip = sin(atan(B * peak_slip_angle))
		base_grip = peak_grip * exp(-over_peak * falloff_sharpness * 0.1)

	# Apply load sensitivity (more load = more grip, but diminishing returns)
	var load_mult = 1.0 + (load_factor - 1.0) * load_sensitivity
	load_mult = clamp(load_mult, 0.5, 1.5)

	# Apply grip coefficient
	grip_force = clamp(base_grip * grip_coefficient * load_mult, 0.0, 1.2)

	# Determine if sliding (past peak)
	is_sliding = slip_angle > peak_slip_angle

	return grip_force

## Calculate slip angle from velocity and heading
## velocity: car's velocity vector
## forward: car's forward direction vector
## Returns slip angle in degrees
static func get_slip_angle(velocity: Vector2, forward: Vector2) -> float:
	if velocity.length() < 5.0:
		return 0.0

	var velocity_angle = velocity.angle()
	var forward_angle = forward.angle()

	var slip = rad_to_deg(angle_difference(forward_angle, velocity_angle))
	return slip

## Get lateral force direction and magnitude
## Returns Vector2 representing the lateral grip force to apply
func get_lateral_force(velocity: Vector2, forward: Vector2, mass: float = 1.0) -> Vector2:
	var right = forward.rotated(PI / 2.0)
	var lateral_velocity = velocity.dot(right)

	# Calculate slip angle
	var slip = get_slip_angle(velocity, forward)
	var grip = calculate_grip(slip)

	# Lateral force opposes lateral velocity
	var force_magnitude = abs(lateral_velocity) * grip * mass
	var force_direction = -sign(lateral_velocity) * right

	return force_direction * force_magnitude

## Configure tire for different types
func configure(tire_type: String) -> void:
	match tire_type:
		"stock":
			grip_coefficient = 1.0
			peak_slip_angle = 8.0
			falloff_sharpness = 0.8
		"sport":
			grip_coefficient = 1.15
			peak_slip_angle = 7.0
			falloff_sharpness = 0.9
		"drift":
			grip_coefficient = 0.95
			peak_slip_angle = 12.0  # Higher slip angle before peak
			falloff_sharpness = 0.5  # Gradual falloff - more forgiving
		"racing":
			grip_coefficient = 1.3
			peak_slip_angle = 6.0   # Sharp peak
			falloff_sharpness = 1.2  # Quick falloff - less forgiving
		"offroad":
			grip_coefficient = 0.85
			peak_slip_angle = 15.0
			falloff_sharpness = 0.4
