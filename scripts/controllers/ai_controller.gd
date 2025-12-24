class_name AIController
extends CarController
## AI controller that follows a waypoint path

## Reference to the racing line path
var waypoint_path: WaypointPath

## Difficulty settings
var max_speed_percent: float = 0.85      # How fast compared to car's max
var lookahead_factor: float = 0.3        # How far ahead to look (scales with speed)
var path_adherence: float = 0.9          # How closely to follow the racing line
var reaction_delay: float = 0.1          # Delay before reacting to changes
var mistake_chance: float = 0.02         # Chance per frame of making a mistake
var corner_brake_distance: float = 100.0 # How early to brake for corners

## Internal state
var target_steer: float = 0.0
var current_steer: float = 0.0
var is_making_mistake: bool = false
var mistake_timer: float = 0.0
var mistake_steer_offset: float = 0.0

## Minimum lookahead distance
const MIN_LOOKAHEAD: float = 50.0
const MAX_LOOKAHEAD: float = 200.0

func get_input() -> InputState:
	var state = InputState.new()

	# Don't move until race starts
	if not RaceManager.is_racing():
		return state

	if car == null or waypoint_path == null:
		return state

	# Get car state
	var car_pos = car.global_position
	var car_rotation = car.rotation
	var car_speed = car.velocity.length()
	var car_forward = Vector2.UP.rotated(car_rotation)

	# Calculate lookahead distance based on speed
	var lookahead_distance = clamp(
		car_speed * lookahead_factor,
		MIN_LOOKAHEAD,
		MAX_LOOKAHEAD
	)

	# Get current position on path
	var current_offset = waypoint_path.get_closest_offset(car_pos)

	# Get target point ahead on path
	var target_offset = current_offset + lookahead_distance
	var target_point = waypoint_path.get_point_at_offset(target_offset)

	# Calculate steering
	var direction_to_target = (target_point - car_pos).normalized()
	var angle_diff = car_forward.angle_to(direction_to_target)

	# Apply steering with smoothing
	target_steer = clamp(angle_diff / (PI * 0.25), -1.0, 1.0) * path_adherence

	# Handle mistakes
	_update_mistakes()
	if is_making_mistake:
		target_steer += mistake_steer_offset

	# Smooth steering (simulates reaction time)
	current_steer = lerp(current_steer, target_steer, 1.0 - reaction_delay)
	state.steer = current_steer

	# Calculate throttle and brake
	var speed_hint = waypoint_path.get_speed_hint_at_offset(target_offset)
	var target_speed = car.MAX_SPEED * max_speed_percent * speed_hint

	# Check for upcoming corner
	var distance_to_corner = waypoint_path.get_distance_to_corner(current_offset)
	if distance_to_corner < corner_brake_distance and car_speed > target_speed * 0.7:
		# Approaching corner - brake
		state.brake = clamp((corner_brake_distance - distance_to_corner) / corner_brake_distance, 0.0, 0.8)
		state.throttle = 0.2  # Light throttle through corner
	elif car_speed < target_speed:
		# Under target speed - accelerate
		state.throttle = clamp((target_speed - car_speed) / 100.0, 0.5, 1.0)
		state.brake = 0.0
	else:
		# At or over target speed - coast or light brake
		state.throttle = 0.3
		state.brake = 0.0 if car_speed < target_speed * 1.1 else 0.2

	# Avoid going too slow
	if car_speed < 50:
		state.throttle = 1.0
		state.brake = 0.0

	return state

func _update_mistakes() -> void:
	if is_making_mistake:
		mistake_timer -= 0.016  # Approximate delta
		if mistake_timer <= 0:
			is_making_mistake = false
			mistake_steer_offset = 0.0
	else:
		# Random chance to make a mistake
		if randf() < mistake_chance:
			is_making_mistake = true
			mistake_timer = randf_range(0.1, 0.3)
			mistake_steer_offset = randf_range(-0.3, 0.3)

## Set difficulty preset
func set_difficulty(difficulty: String) -> void:
	match difficulty:
		"easy":
			max_speed_percent = 0.70
			lookahead_factor = 0.25
			path_adherence = 0.7
			reaction_delay = 0.2
			mistake_chance = 0.05
			corner_brake_distance = 150.0
		"medium":
			max_speed_percent = 0.85
			lookahead_factor = 0.3
			path_adherence = 0.85
			reaction_delay = 0.1
			mistake_chance = 0.02
			corner_brake_distance = 100.0
		"hard":
			max_speed_percent = 0.95
			lookahead_factor = 0.35
			path_adherence = 0.95
			reaction_delay = 0.05
			mistake_chance = 0.005
			corner_brake_distance = 80.0
		"expert":
			max_speed_percent = 1.0
			lookahead_factor = 0.4
			path_adherence = 1.0
			reaction_delay = 0.02
			mistake_chance = 0.0
			corner_brake_distance = 60.0

## Set the waypoint path for this AI to follow
func set_waypoint_path(path: WaypointPath) -> void:
	waypoint_path = path
