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
var throttle_smoothness: float = 0.8     # How optimal throttle is (1.0 = perfect, lower = more like player)

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

## AI constants (loaded from config)
var STUCK_SPEED_THRESHOLD: float = 20.0
var STUCK_TIME_THRESHOLD: float = 0.8
var UNSTUCK_BRAKE_TIME: float = 0.2
var UNSTUCK_REVERSE_TIME: float = 0.4
var UNSTUCK_FORWARD_TIME: float = 0.3
var AVOIDANCE_STEER_STRENGTH: float = 0.5
var MIN_LOOKAHEAD: float = 50.0
var MAX_LOOKAHEAD: float = 200.0

## Collision avoidance constants (loaded from config)
var AVOIDANCE_DISTANCE: float = 80.0
var AVOIDANCE_SIDE_DISTANCE: float = 40.0
var AVOIDANCE_SLOWDOWN_DISTANCE: float = 60.0

## Pit strategy settings
var pit_damage_threshold: float = 0.4  # Seek pit when total damage > 40%
var critical_damage_threshold: float = 0.6  # Drive very cautiously above 60%
var is_seeking_pit: bool = false
var pit_stop_zone: Node2D = null  # Reference to pit stop area
var damage_speed_penalty: float = 0.0  # 0.0 to 0.3 based on damage
var damage_caution_factor: float = 1.0  # Reduces aggression when damaged

func _load_constants() -> void:
	var constants = ConfigManager.get_ai_constants()
	STUCK_SPEED_THRESHOLD = constants.get("stuck_speed_threshold", 20.0)
	STUCK_TIME_THRESHOLD = constants.get("stuck_time_threshold", 0.8)
	UNSTUCK_BRAKE_TIME = constants.get("unstuck_brake_time", 0.2)
	UNSTUCK_REVERSE_TIME = constants.get("unstuck_reverse_time", 0.4)
	UNSTUCK_FORWARD_TIME = constants.get("unstuck_forward_time", 0.3)
	AVOIDANCE_STEER_STRENGTH = constants.get("avoidance_steer_strength", 0.5)
	MIN_LOOKAHEAD = constants.get("min_lookahead", 50.0)
	MAX_LOOKAHEAD = constants.get("max_lookahead", 200.0)
	AVOIDANCE_DISTANCE = constants.get("avoidance_distance", 80.0)
	AVOIDANCE_SIDE_DISTANCE = constants.get("avoidance_side_distance", 40.0)
	AVOIDANCE_SLOWDOWN_DISTANCE = constants.get("avoidance_slowdown_distance", 60.0)

func get_input() -> InputState:
	var state = InputState.new()

	# Don't move until race starts
	if not RaceManager.is_racing():
		return state

	if car == null or waypoint_path == null:
		return state

	# Update damage awareness
	_update_damage_awareness()

	# Get car state
	var car_pos = car.global_position
	var car_rotation = car.rotation
	var car_speed = car.velocity.length()
	# Note: Car sprite is rotated 180° so use DOWN as base forward
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

	# Proactive collision avoidance - steer away from nearby cars
	var nearby_cars = _get_nearby_cars()
	var avoidance = _calculate_avoidance_steering(nearby_cars)
	target_steer += avoidance

	# Apply avoidance steering if stuck (fallback)
	if stuck_timer > STUCK_TIME_THRESHOLD * 0.5:
		# Start steering to avoid obstacle before fully stuck
		target_steer += stuck_steer_direction * AVOIDANCE_STEER_STRENGTH

	# Smooth steering (simulates reaction time)
	current_steer = lerp(current_steer, target_steer, 1.0 - reaction_delay)
	state.steer = clamp(current_steer, -1.0, 1.0)

	# Calculate throttle and brake
	var speed_hint = waypoint_path.get_speed_hint_at_offset(target_offset)
	var effective_max_speed = max_speed_percent * (1.0 - damage_speed_penalty)
	var target_speed = car.MAX_SPEED * effective_max_speed * speed_hint

	# Check for upcoming corner
	var distance_to_corner = waypoint_path.get_distance_to_corner(current_offset)
	if distance_to_corner < corner_brake_distance and car_speed > target_speed * 0.7:
		# Approaching corner - brake
		state.brake = clamp((corner_brake_distance - distance_to_corner) / corner_brake_distance, 0.0, 0.8)
		state.throttle = 0.1 * throttle_smoothness  # Less throttle through corner
	elif car_speed < target_speed:
		# Under target speed - accelerate
		# More player-like: binary throttle with some variation
		var speed_diff_ratio = (target_speed - car_speed) / target_speed
		if speed_diff_ratio > (1.0 - throttle_smoothness) * 0.5:
			# Need more speed - full throttle (like player holding gas)
			state.throttle = 0.9 + randf() * 0.1
		else:
			# Close to target - partial throttle with variation
			state.throttle = clamp(speed_diff_ratio * 2.0 + randf() * 0.2, 0.3, 0.8) * throttle_smoothness
		state.brake = 0.0
	else:
		# At or over target speed - coast or light brake (less optimal than before)
		state.throttle = 0.1 + randf() * 0.2
		state.brake = 0.0 if car_speed < target_speed * 1.05 else 0.3

	# Avoid going too slow - but with slight delay like player reaction
	if car_speed < 40:
		state.throttle = 0.85 + randf() * 0.15
		state.brake = 0.0

	# Slow down when very close to other cars to reduce bumping
	if not nearby_cars.is_empty():
		var closest_dist = nearby_cars[0]["distance"]
		if closest_dist < AVOIDANCE_SLOWDOWN_DISTANCE:
			var slowdown_factor = 0.5 + 0.5 * (closest_dist / AVOIDANCE_SLOWDOWN_DISTANCE)
			state.throttle *= slowdown_factor

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

## Set difficulty preset from ConfigManager
func set_difficulty(difficulty: String) -> void:
	current_difficulty = difficulty

	# Load constants first
	_load_constants()

	# Load difficulty settings from config
	var settings = ConfigManager.get_ai_difficulty_settings(difficulty)
	if settings.is_empty():
		push_warning("Unknown AI difficulty: %s, using medium" % difficulty)
		settings = ConfigManager.get_ai_difficulty_settings("medium")

	max_speed_percent = settings.get("max_speed_percent", 0.75)
	lookahead_factor = settings.get("lookahead_factor", 0.3)
	path_adherence = settings.get("path_adherence", 0.85)
	reaction_delay = settings.get("reaction_delay", 0.1)
	mistake_chance = settings.get("mistake_chance", 0.03)
	corner_brake_distance = settings.get("corner_brake_distance", 100.0)
	throttle_smoothness = settings.get("throttle_smoothness", 0.65)

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

## Get nearby cars for collision avoidance
func _get_nearby_cars() -> Array:
	var nearby = []
	if car == null:
		return nearby
	var my_pos = car.global_position
	for other_car in RaceManager.registered_cars:
		if other_car == car:
			continue
		var dist = my_pos.distance_to(other_car.global_position)
		if dist < AVOIDANCE_DISTANCE:
			nearby.append({"car": other_car, "distance": dist})
	# Sort by distance (closest first)
	nearby.sort_custom(func(a, b): return a["distance"] < b["distance"])
	return nearby

## Calculate steering adjustment to avoid nearby cars
func _calculate_avoidance_steering(nearby_cars: Array) -> float:
	if nearby_cars.is_empty():
		return 0.0

	var car_forward = Vector2.UP.rotated(car.rotation)
	var car_right = car_forward.rotated(PI / 2)
	var avoidance_steer = 0.0

	for nearby in nearby_cars:
		var other = nearby["car"]
		var to_other = other.global_position - car.global_position
		var forward_dot = to_other.normalized().dot(car_forward)
		var right_dot = to_other.normalized().dot(car_right)

		# Only avoid cars ahead or beside (not behind)
		if forward_dot < -0.2:
			continue

		var dist = nearby["distance"]
		var influence = 1.0 - (dist / AVOIDANCE_DISTANCE)

		# Steer away from car (opposite of right_dot)
		if abs(right_dot) > 0.1:
			avoidance_steer -= sign(right_dot) * influence * 0.5
		elif forward_dot > 0.5:
			# Car directly ahead - pick a side based on racing line
			avoidance_steer += 0.3 * influence

	return clamp(avoidance_steer, -0.6, 0.6)

# =============================================================================
# Pit Strategy and Damage Awareness
# =============================================================================

## Update damage awareness and pit strategy
func _update_damage_awareness() -> void:
	if not DamageSystem or car == null:
		damage_speed_penalty = 0.0
		damage_caution_factor = 1.0
		is_seeking_pit = false
		return

	var damage_state = DamageSystem.get_damage_state(car)
	if damage_state == null:
		damage_speed_penalty = 0.0
		damage_caution_factor = 1.0
		is_seeking_pit = false
		return

	# Calculate total damage percentage
	var total_damage = damage_state.get_total_damage_percent()

	# Adjust driving based on damage level
	if total_damage >= critical_damage_threshold:
		# Critical damage - drive very cautiously
		damage_speed_penalty = 0.25  # 25% slower
		damage_caution_factor = 0.5  # Much less aggressive
		is_seeking_pit = true
	elif total_damage >= pit_damage_threshold:
		# Moderate damage - drive more carefully, consider pit
		damage_speed_penalty = 0.15  # 15% slower
		damage_caution_factor = 0.75  # Less aggressive
		is_seeking_pit = _should_seek_pit(total_damage)
	else:
		# Low/no damage - drive normally
		damage_speed_penalty = 0.0
		damage_caution_factor = 1.0
		is_seeking_pit = false

## Determine if AI should seek the pit (weighs damage vs race position)
func _should_seek_pit(damage_percent: float) -> bool:
	# Get current race position
	var position = RaceManager.get_car_position(car)
	var total_cars = RaceManager.registered_cars.size()

	# If leading or close to lead, be more reluctant to pit
	if position <= 2:
		# Only pit if damage is very high
		return damage_percent >= 0.5

	# If in the middle of pack, consider pit more readily
	if position <= total_cars / 2:
		return damage_percent >= pit_damage_threshold

	# If at the back, pit readily since we have less to lose
	return damage_percent >= pit_damage_threshold * 0.8

## Set pit stop zone reference
func set_pit_stop_zone(zone: Node2D) -> void:
	pit_stop_zone = zone

## Check if car is near pit and should enter
func is_near_pit() -> bool:
	if pit_stop_zone == null or car == null:
		return false

	var distance = car.global_position.distance_to(pit_stop_zone.global_position)
	return distance < 100.0  # Within 100 pixels of pit

## Get whether AI is currently seeking pit
func get_is_seeking_pit() -> bool:
	return is_seeking_pit

## Get current damage-based speed penalty (0.0 to 0.3)
func get_damage_speed_penalty() -> float:
	return damage_speed_penalty
