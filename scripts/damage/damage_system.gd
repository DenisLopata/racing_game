extends Node
## DamageSystem - Autoload singleton for managing car damage
##
## Handles collision detection, damage calculation, and tracking damage states
## for all cars in a race. Register in project.godot as autoload.

signal damage_taken(car: Node, part: String, amount: float, new_health: float)
signal part_failed(car: Node, part: String)
signal car_repaired(car: Node, part: String)
signal car_totaled(car: Node, reason: String)

# DNF threshold - car is totaled if total damage exceeds this
const DNF_DAMAGE_THRESHOLD: float = 0.7  # 70% total damage

# Configuration
var config: DamageConfig

# Damage reports per car for post-race summary
var _damage_reports: Dictionary = {}  # car_id -> DamageReport

# Track which cars have been totaled (to prevent repeated signals)
var _totaled_cars: Dictionary = {}  # car_id -> bool

# Track damage state for all cars in current race
# car instance_id -> CarDamageState
var _car_damage_states: Dictionary = {}

# Cooldown to prevent rapid damage from same collision
var _collision_cooldowns: Dictionary = {}  # car_id -> last_collision_time
const COLLISION_COOLDOWN: float = 0.1  # 100ms between damage events

func _ready() -> void:
	config = DamageConfig.load_from_config()

## Register a car for damage tracking
func register_car(car: Node, initial_state: CarDamageState = null) -> void:
	var car_id = car.get_instance_id()
	if initial_state:
		_car_damage_states[car_id] = initial_state
	else:
		_car_damage_states[car_id] = CarDamageState.new(config)
	_collision_cooldowns[car_id] = 0.0

## Unregister a car (call when car is removed from scene)
func unregister_car(car: Node) -> void:
	var car_id = car.get_instance_id()
	_car_damage_states.erase(car_id)
	_collision_cooldowns.erase(car_id)

## Clear all registered cars (call at race end)
func clear_all_cars() -> void:
	_car_damage_states.clear()
	_collision_cooldowns.clear()

## Get damage state for a car
func get_damage_state(car: Node) -> CarDamageState:
	var car_id = car.get_instance_id()
	if not _car_damage_states.has(car_id):
		register_car(car)
	return _car_damage_states[car_id]

## Process a collision event from a car
## Call this from car's _physics_process after move_and_slide
func process_collision(car: Node, collision: KinematicCollision2D) -> void:
	var car_id = car.get_instance_id()

	# Check cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	if _collision_cooldowns.has(car_id):
		if current_time - _collision_cooldowns[car_id] < COLLISION_COOLDOWN:
			return

	# Get car velocity (assuming car has velocity property)
	var velocity = car.get("velocity")
	if velocity == null:
		return

	var impact_speed = velocity.length()

	# Check minimum damage threshold
	if impact_speed < config.min_damage_speed:
		return

	# Determine collision type
	var collider = collision.get_collider()
	var collision_type = "wall"

	if collider and collider.is_in_group("cars"):
		collision_type = "car"
		# Also apply damage to the other car
		_apply_collision_damage(collider, collision, car, collision_type)

	# Apply damage to this car
	_apply_collision_damage(car, collision, collider, collision_type)

	# Update cooldown
	_collision_cooldowns[car_id] = current_time

## Internal: Apply damage from a collision to a car
func _apply_collision_damage(car: Node, collision: KinematicCollision2D, _other: Node, collision_type: String) -> void:
	# Don't apply damage to totaled cars
	if is_car_totaled(car):
		return

	# Check for shield protection
	if ItemManager and ItemManager.has_shield(car):
		ItemManager.consume_shield(car)
		print("[DamageSystem] Shield blocked damage for %s" % car.name)
		return

	var damage_state = get_damage_state(car)
	var velocity = car.get("velocity")
	if velocity == null:
		return

	var impact_speed = velocity.length()
	var normal = collision.get_normal()

	# Get affected parts based on impact direction
	var affected_parts = _get_affected_parts(car, normal, impact_speed)

	# Apply damage to each affected part
	for part in affected_parts:
		var damage = config.calculate_damage(impact_speed, part, collision_type)
		if damage > 0:
			var was_working = not damage_state.is_part_failed(part)
			damage_state.apply_damage(part, damage)
			var new_health = damage_state.get_part_health(part)

			# Record event for damage report
			_record_damage_event(car, part, damage, impact_speed)

			damage_taken.emit(car, part, damage, new_health)

			# Check if part just failed
			if was_working and damage_state.is_part_failed(part):
				part_failed.emit(car, part)

	# Check if car should be totaled after damage
	_check_dnf(car)

## Determine which parts are affected based on impact direction
func _get_affected_parts(car: Node, impact_normal: Vector2, impact_speed: float) -> Array[String]:
	var rotation = car.get("rotation")
	if rotation == null:
		rotation = 0.0

	# Get car's forward and right vectors
	# Note: Car sprite is rotated 180° so use DOWN as base forward
	var car_forward = Vector2.UP.rotated(rotation)
	var car_right = car_forward.rotated(PI / 2)

	# Calculate dot products to determine impact direction relative to car
	var forward_dot = impact_normal.dot(car_forward)
	var side_dot = impact_normal.dot(car_right)

	var parts: Array[String] = []

	# Front impact (normal points backward relative to car, meaning we hit something in front)
	if forward_dot < -0.5:
		parts.append("engines")
		parts.append("suspensions")

	# Rear impact
	if forward_dot > 0.5:
		parts.append("engines")  # Transmission damage
		parts.append("spoilers")

	# Side impact (left or right)
	if abs(side_dot) > 0.5:
		parts.append("tires")
		parts.append("suspensions")

	# High-speed impacts always risk brake damage
	if impact_speed > config.severe_damage_speed:
		if not "brakes" in parts:
			parts.append("brakes")

	# If no specific parts affected (glancing blow), minimal scrape damage
	if parts.is_empty():
		parts.append("spoilers")  # Cosmetic damage

	return parts

## Process scrape damage (for continuous wall contact)
func process_scrape(car: Node, contact_speed: float) -> void:
	if contact_speed < config.min_damage_speed * 0.5:
		return

	var damage_state = get_damage_state(car)
	var damage = config.calculate_damage(contact_speed, "spoilers", "scrape")

	if damage > 0:
		damage_state.apply_damage("spoilers", damage)
		var new_health = damage_state.get_part_health("spoilers")
		damage_taken.emit(car, "spoilers", damage, new_health)

## Repair a specific part on a car
func repair_part(car: Node, part: String) -> void:
	var damage_state = get_damage_state(car)
	damage_state.repair_part(part)
	car_repaired.emit(car, part)

## Repair all parts on a car
func repair_all(car: Node) -> void:
	var damage_state = get_damage_state(car)
	for part in damage_state.part_health:
		damage_state.repair_part(part)
		car_repaired.emit(car, part)

## Get repair cost for a car's current damage
func get_repair_cost(car: Node, part: String) -> int:
	var damage_state = get_damage_state(car)
	var damage_percent = 1.0 - damage_state.get_part_health(part)
	return config.get_repair_cost(part, damage_percent)

## Get total repair cost for all damage
func get_total_repair_cost(car: Node) -> int:
	var damage_state = get_damage_state(car)
	return config.get_total_repair_cost(damage_state.part_health)

# =============================================================================
# DNF / Car Totaling System
# =============================================================================

## Check if a car should be totaled (DNF)
func _check_dnf(car: Node) -> void:
	var car_id = car.get_instance_id()

	# Don't check already totaled cars
	if _totaled_cars.get(car_id, false):
		return

	var damage_state = get_damage_state(car)
	var reason = ""

	# Check for part failure
	if damage_state.has_failed_parts():
		var failed_parts = damage_state.get_failed_parts()
		reason = "Part failure: " + _get_part_display_name(failed_parts[0])
	# Check for excessive total damage
	elif damage_state.get_total_damage_percent() > DNF_DAMAGE_THRESHOLD:
		reason = "Excessive damage (%.0f%%)" % (damage_state.get_total_damage_percent() * 100)

	if not reason.is_empty():
		_totaled_cars[car_id] = true
		car_totaled.emit(car, reason)

## Get display name for a part
func _get_part_display_name(part: String) -> String:
	match part:
		"engines": return "Engine"
		"tires": return "Tires"
		"brakes": return "Brakes"
		"suspensions": return "Suspension"
		"spoilers": return "Spoiler"
		_: return part.capitalize()

## Check if a car is totaled
func is_car_totaled(car: Node) -> bool:
	var car_id = car.get_instance_id()
	return _totaled_cars.get(car_id, false)

# =============================================================================
# Damage Report Tracking
# =============================================================================

## Start tracking damage for a race (call at race start)
func start_race_tracking(car: Node) -> void:
	var car_id = car.get_instance_id()
	var damage_state = get_damage_state(car)

	var report = DamageReport.new()
	report.pre_race_health = damage_state.part_health.duplicate()
	report.race_start_time = Time.get_ticks_msec() / 1000.0
	_damage_reports[car_id] = report

	# Reset totaled state for new race
	_totaled_cars[car_id] = false

## Record a damage event for the report
func _record_damage_event(car: Node, part: String, amount: float, impact_speed: float) -> void:
	var car_id = car.get_instance_id()
	if not _damage_reports.has(car_id):
		return

	var report = _damage_reports[car_id] as DamageReport
	report.record_event(part, amount, impact_speed)

## Finalize damage report at race end
func finalize_race_report(car: Node) -> DamageReport:
	var car_id = car.get_instance_id()
	if not _damage_reports.has(car_id):
		return null

	var report = _damage_reports[car_id] as DamageReport
	var damage_state = get_damage_state(car)
	report.post_race_health = damage_state.part_health.duplicate()
	report.finalize(config)

	return report

## Get damage report for a car
func get_damage_report(car: Node) -> DamageReport:
	var car_id = car.get_instance_id()
	return _damage_reports.get(car_id, null)

## Clear damage reports (call at race end after showing results)
func clear_damage_reports() -> void:
	_damage_reports.clear()
	_totaled_cars.clear()
