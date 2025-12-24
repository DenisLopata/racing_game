class_name AIController
extends CarController
## AI controller that follows a waypoint path

## Reference to the racing line path
var waypoint_path: WaypointPath

## Available paths for different difficulties
var difficulty_paths: Dictionary = {}  # "easy" -> WaypointPath, etc.
var current_difficulty: String = "medium"

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

## Stuck detection and avoidance
var stuck_timer: float = 0.0
var stuck_steer_direction: float = 1.0  # 1 or -1
var is_unstucking: bool = false
var unstuck_phase: int = 0  # 0 = brake, 1 = reverse, 2 = forward with steer
var unstuck_timer: float = 0.0
var last_position: Vector2 = Vector2.ZERO
var position_check_timer: float = 0.0

const STUCK_SPEED_THRESHOLD: float = 30.0  # Consider stuck if below this speed
const STUCK_TIME_THRESHOLD: float = 0.4    # Time before considering stuck
const UNSTUCK_BRAKE_TIME: float = 0.3      # Time to brake before reversing
const UNSTUCK_REVERSE_TIME: float = 0.8    # Time to reverse
const UNSTUCK_FORWARD_TIME: float = 0.5    # Time to go forward with steering
const AVOIDANCE_STEER_STRENGTH: float = 1.0

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

	# Update stuck detection
	_update_stuck_detection(car_pos, car_speed)

	# If unstucking, handle unstuck behavior
	if is_unstucking:
		return _get_unstuck_input(car_speed)

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

	# Apply avoidance steering if stuck
	if stuck_timer > STUCK_TIME_THRESHOLD * 0.5:
		# Start steering to avoid obstacle before fully stuck
		target_steer += stuck_steer_direction * AVOIDANCE_STEER_STRENGTH

	# Smooth steering (simulates reaction time)
	current_steer = lerp(current_steer, target_steer, 1.0 - reaction_delay)
	state.steer = clamp(current_steer, -1.0, 1.0)

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

## Update stuck detection
func _update_stuck_detection(car_pos: Vector2, car_speed: float) -> void:
	var delta = 0.016  # Approximate frame time

	# Don't detect stuck while already unstucking
	if is_unstucking:
		return

	# Initialize last_position on first call
	if last_position == Vector2.ZERO:
		last_position = car_pos

	# Track position over time - more reliable than speed when cars collide
	position_check_timer += delta

	if position_check_timer > 0.2:  # Check every 0.2 seconds
		var distance_moved = car_pos.distance_to(last_position)

		# If we've barely moved, we're stuck
		if distance_moved < 10.0:
			stuck_timer += 0.25
		else:
			# We're moving, reduce stuck timer
			stuck_timer = maxf(0.0, stuck_timer - 0.15)

		last_position = car_pos
		position_check_timer = 0.0

	# Also check raw speed as backup
	if car_speed < STUCK_SPEED_THRESHOLD:
		stuck_timer += delta

	# Trigger unstuck routine
	if stuck_timer > STUCK_TIME_THRESHOLD:
		is_unstucking = true
		unstuck_phase = 0
		unstuck_timer = UNSTUCK_BRAKE_TIME
		stuck_steer_direction = 1.0 if randf() > 0.5 else -1.0
		stuck_timer = 0.0

## Get input during unstuck routine (3 phases: brake, reverse, forward+steer)
func _get_unstuck_input(car_speed: float) -> InputState:
	var state = InputState.new()
	var delta = 0.016

	unstuck_timer -= delta

	if unstuck_timer <= 0:
		# Move to next phase
		unstuck_phase += 1
		if unstuck_phase == 1:
			unstuck_timer = UNSTUCK_REVERSE_TIME
		elif unstuck_phase == 2:
			unstuck_timer = UNSTUCK_FORWARD_TIME
		else:
			# Done with unstuck routine
			is_unstucking = false
			unstuck_phase = 0
			# Alternate direction for next time
			stuck_steer_direction *= -1.0
			return state

	match unstuck_phase:
		0:  # Brake to stop
			state.throttle = 0.0
			state.brake = 1.0
			state.steer = 0.0
		1:  # Reverse with steering
			state.throttle = 0.0
			state.brake = 1.0  # Brake = reverse when slow
			state.steer = stuck_steer_direction * 0.8
		2:  # Forward with opposite steering to get around obstacle
			state.throttle = 1.0
			state.brake = 0.0
			state.steer = -stuck_steer_direction * 0.6

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
	current_difficulty = difficulty

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

	# Select the appropriate path for this difficulty
	if difficulty in difficulty_paths:
		waypoint_path = difficulty_paths[difficulty]

## Set all available difficulty paths
func set_difficulty_paths(paths: Dictionary) -> void:
	difficulty_paths = paths
	# Apply current difficulty path if available
	if current_difficulty in difficulty_paths:
		waypoint_path = difficulty_paths[current_difficulty]

## Set the waypoint path for this AI to follow
func set_waypoint_path(path: WaypointPath) -> void:
	waypoint_path = path
