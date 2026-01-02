class_name CollisionResponse
extends RefCounted
## Handles realistic collision bounce and deflection for cars

signal collision_processed(bounce_velocity: Vector2, spin: float, severity: float)

# Collision parameters
var wall_restitution: float = 0.4      # Bounciness off walls (0-1)
var car_restitution: float = 0.6       # Bounciness off other cars
var wall_friction: float = 0.7         # Friction along walls
var car_friction: float = 0.5          # Friction between cars

# Spin parameters
var spin_factor: float = 0.015         # How much collisions induce spin
var max_spin_rate: float = 8.0         # Max angular velocity from collision
var spin_decay: float = 3.0            # How quickly spin decays

# Severity thresholds
var minor_collision_speed: float = 50.0
var major_collision_speed: float = 150.0
var severe_collision_speed: float = 250.0

# Current collision-induced spin
var collision_spin: float = 0.0

## Process a collision and return the response
## velocity: car's current velocity
## collision: KinematicCollision2D from move_and_slide
## car_rotation: car's current rotation
## is_car_collision: whether we hit another car
## Returns dictionary with new velocity and spin
func process_collision(velocity: Vector2, collision: KinematicCollision2D,
					   car_rotation: float, is_car_collision: bool = false) -> Dictionary:
	var normal = collision.get_normal()
	var collision_point = collision.get_position()

	# Get incoming speed along collision normal
	var impact_speed = -velocity.dot(normal)

	if impact_speed < 10.0:
		# Glancing blow, minimal response
		return {"velocity": velocity, "spin": 0.0, "severity": 0.0}

	# Calculate severity (0-1)
	var severity = _calculate_severity(impact_speed)

	# Choose restitution and friction based on collision type
	var restitution = car_restitution if is_car_collision else wall_restitution
	var friction = car_friction if is_car_collision else wall_friction

	# Decompose velocity into normal and tangent components
	var normal_velocity = normal * velocity.dot(normal)
	var tangent_velocity = velocity - normal_velocity

	# Apply restitution (bounce)
	var bounce_normal = -normal_velocity * restitution

	# Apply friction to tangent (scrubbing along surface)
	var friction_tangent = tangent_velocity * (1.0 - friction * severity)

	# Combine for final velocity
	var new_velocity = bounce_normal + friction_tangent

	# Calculate spin from off-center impact
	var spin = _calculate_spin(collision_point, car_rotation, normal, impact_speed, is_car_collision)

	collision_processed.emit(new_velocity, spin, severity)

	return {
		"velocity": new_velocity,
		"spin": spin,
		"severity": severity
	}

## Calculate collision severity (0-1)
func _calculate_severity(impact_speed: float) -> float:
	if impact_speed < minor_collision_speed:
		return impact_speed / minor_collision_speed * 0.3
	elif impact_speed < major_collision_speed:
		var t = (impact_speed - minor_collision_speed) / (major_collision_speed - minor_collision_speed)
		return 0.3 + t * 0.4
	elif impact_speed < severe_collision_speed:
		var t = (impact_speed - major_collision_speed) / (severe_collision_speed - major_collision_speed)
		return 0.7 + t * 0.3
	else:
		return 1.0

## Calculate spin induced by collision
func _calculate_spin(collision_point: Vector2, car_rotation: float,
					 normal: Vector2, impact_speed: float, is_car: bool) -> float:
	# Determine where on the car the impact occurred
	# Note: Car sprite is rotated 180° so use DOWN as base forward
	var car_forward = Vector2.UP.rotated(car_rotation)
	var car_right = car_forward.rotated(PI / 2.0)

	# Impact direction relative to car
	var impact_forward = normal.dot(car_forward)
	var impact_side = normal.dot(car_right)

	# Side impacts cause more spin
	var spin_amount = impact_side * impact_speed * spin_factor

	# Front/rear impacts cause less spin but add based on angle
	spin_amount += impact_forward * impact_speed * spin_factor * 0.3

	# Car-to-car collisions cause more chaotic spin
	if is_car:
		spin_amount *= 1.5

	# Clamp to max
	spin_amount = clamp(spin_amount, -max_spin_rate, max_spin_rate)

	return spin_amount

## Update collision spin over time (decay)
func update_spin(delta: float) -> float:
	collision_spin = lerp(collision_spin, 0.0, delta * spin_decay)
	return collision_spin

## Apply accumulated spin
func add_spin(spin: float) -> void:
	collision_spin += spin
	collision_spin = clamp(collision_spin, -max_spin_rate, max_spin_rate)

## Get current spin to apply to car rotation
func get_spin() -> float:
	return collision_spin

## Process wall scrape (continuous contact)
## Returns friction force to apply
func process_scrape(velocity: Vector2, normal: Vector2, contact_speed: float) -> Vector2:
	if contact_speed < 20.0:
		return Vector2.ZERO

	# Calculate tangent direction (along wall)
	var tangent = normal.rotated(PI / 2.0)
	if velocity.dot(tangent) < 0:
		tangent = -tangent

	# Friction opposes movement along wall
	var friction_force = -tangent * contact_speed * wall_friction * 0.5

	return friction_force

## Check if collision should trigger spinout
func should_spinout(severity: float, current_grip: float) -> bool:
	# High severity + low grip = spinout
	return severity > 0.7 and current_grip < 0.5

## Get recommended recovery time based on severity
func get_recovery_time(severity: float) -> float:
	return severity * 0.5  # Up to 0.5 seconds of reduced control

## Configure collision response
func configure(style: String) -> void:
	match style:
		"arcade":
			wall_restitution = 0.5
			car_restitution = 0.7
			spin_factor = 0.01
			max_spin_rate = 5.0
		"realistic":
			wall_restitution = 0.3
			car_restitution = 0.5
			spin_factor = 0.02
			max_spin_rate = 10.0
		"bumper_cars":
			wall_restitution = 0.8
			car_restitution = 0.9
			spin_factor = 0.025
			max_spin_rate = 12.0
		_:  # hybrid default
			pass
