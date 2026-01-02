class_name Car
extends CharacterBody2D

@export_enum("FWD", "RWD", "AWD")
var drive_type: String = "RWD"

# Active tuning preset
@export_enum("arcade", "realistic", "hybrid")
var tuning_mode: String = "hybrid"

# Controller (player or AI)
var controller: CarController = null
var car_id: int = -1

# Current input state from controller
var current_input: CarController.InputState = null
# Core variables (will be set from tuning dictionary, defaults ensure car always works)
var ACCELERATION: float = 400.0
var MAX_SPEED: float = 340.0
var FRICTION: float = 300.0
var BRAKE_FORCE: float = 600.0
var ROTATION_SPEED: float = 2.6
var AIR_DRAG_COEFF: float = 0.0006
var DRIFT_THRESHOLD: float = 100.0

# Base stats (before damage, for real-time recalculation)
var _base_acceleration: float
var _base_max_speed: float
var _base_brake_force: float
var _base_rotation_speed: float
var _base_drag_coeff: float
var _base_lateral_grip: float

# Enhanced physics systems
var use_enhanced_physics: bool = true
var tire_model: TireModel = null
var weight_transfer: WeightTransfer = null
var transmission: Transmission = null
var collision_response: CollisionResponse = null

# Enhanced physics parameters (from config)
var tire_grip_coefficient: float = 1.0
var weight_transfer_intensity: float = 0.7
var collision_bounce: float = 0.4
var handbrake_grip_reduction: float = 0.2
var counter_steer_assist: float = 0.25

# Drift and handling state
var current_slip_angle: float = 0.0
var is_drifting: bool = false
var is_handbrake_active: bool = false
var drift_angle: float = 0.0
var counter_steer_active: bool = false
var angular_velocity: float = 0.0  # For spin from collisions

# Audio systems
var engine_audio: EngineAudio = null
var tire_screech_audio: TireScreechAudio = null
var transmission_audio: TransmissionAudio = null
var use_procedural_audio: bool = true

signal drift_marks_finished(points: PackedVector2Array)
signal update_speed(current_speed: String)
signal gear_changed(gear: int)
signal tire_blowout()
signal engine_failed()
signal car_totaled(reason: String)

# Totaled state
var is_totaled: bool = false
var _totaled_reason: String = ""

# Speed
var displayed_speed: float = 0.0

# Surface handling
var current_surface: String = "road"
var surface_props: SurfaceProperties

# Nodes
@onready var drift_particles: GPUParticles2D = $GPUParticles2D
@onready var tiremarks_pos: Marker2D = $TiremarksPos
@onready var tile_map_layer: TileMapLayer = $"../TileMapLayer"

var tire_marks: Line2D
var surface_manager: SurfaceManager
var drift_manager: DriftManager

# Drivetrain modifier cache (loaded from config)
var drivetrain_modifier: Dictionary = {}

# Part modifiers (from equipped upgrades)
var part_modifiers: CarModifiers = null

# Whether this car uses player upgrades (only player car)
var use_player_upgrades: bool = false

# -------------------------
# Lifecycle
# -------------------------
func _ready() -> void:
	# Add to cars group for collision detection
	add_to_group("cars")

	apply_tuning(tuning_mode)

	drift_manager = DriftManager.new()
	add_child(drift_manager)

	# Initialize enhanced physics systems
	_init_enhanced_physics()

	# Register with damage system
	_register_damage_system()

## Initialize enhanced physics components
func _init_enhanced_physics() -> void:
	tire_model = TireModel.new()
	weight_transfer = WeightTransfer.new()
	transmission = Transmission.new()
	collision_response = CollisionResponse.new()

	# Configure based on drivetrain
	var weight_dist = drivetrain_modifier.get("weight_distribution", "balanced")
	weight_transfer.configure(weight_dist)

	# Connect transmission signal
	transmission.gear_changed.connect(_on_gear_changed)

	# Load enhanced config
	_load_enhanced_config()

	# Initialize audio systems
	_init_audio_systems()

## Initialize procedural audio systems
func _init_audio_systems() -> void:
	if not use_procedural_audio:
		return

	# Engine audio
	engine_audio = EngineAudio.new()
	engine_audio.name = "EngineAudio"
	add_child(engine_audio)

	# Configure based on car type (could be from config)
	var engine_type = drivetrain_modifier.get("engine_type", "inline4")
	engine_audio.configure(engine_type)

	# Tire screech audio
	tire_screech_audio = TireScreechAudio.new()
	tire_screech_audio.name = "TireScreechAudio"
	add_child(tire_screech_audio)

	# Configure based on tire type
	var tire_type = "stock"
	if part_modifiers:
		tire_type = part_modifiers.get_meta("tire_type", "stock") if part_modifiers.has_meta("tire_type") else "stock"
	tire_screech_audio.configure(tire_type)

	# Transmission audio
	transmission_audio = TransmissionAudio.new()
	transmission_audio.name = "TransmissionAudio"
	add_child(transmission_audio)

	# Connect to transmission
	if transmission:
		transmission_audio.connect_transmission(transmission)

func _exit_tree() -> void:
	# Unregister from damage system
	if DamageSystem:
		DamageSystem.unregister_car(self)

func _register_damage_system() -> void:
	if not DamageSystem:
		return

	# For player car, load damage state from progress
	if use_player_upgrades and PlayerProgress:
		var saved_damage = PlayerProgress.get_damage_state()
		DamageSystem.register_car(self, saved_damage)
	else:
		DamageSystem.register_car(self)

	# Connect to damage signals for real-time stat updates
	DamageSystem.damage_taken.connect(_on_damage_taken)
	DamageSystem.part_failed.connect(_on_part_failed)
	DamageSystem.car_totaled.connect(_on_car_totaled)

# Apply preset values from ConfigManager
func apply_tuning(mode: String) -> void:
	var preset = ConfigManager.get_car_preset(mode)
	if preset.is_empty():
		push_warning("Unknown tuning mode: %s" % mode)
		return

	# Load base stats from preset
	ACCELERATION = preset.get("acceleration", 400.0)
	MAX_SPEED = preset.get("max_speed", 340.0)
	FRICTION = preset.get("friction", 300.0)
	BRAKE_FORCE = preset.get("brake_force", 600.0)
	ROTATION_SPEED = preset.get("rotation_speed", 2.6)
	AIR_DRAG_COEFF = preset.get("air_drag_coeff", 0.0006)
	DRIFT_THRESHOLD = preset.get("drift_threshold", 100.0)

	# Load enhanced physics settings from preset
	use_enhanced_physics = preset.get("use_enhanced_physics", true)
	tire_grip_coefficient = preset.get("tire_grip_coefficient", 1.0)
	weight_transfer_intensity = preset.get("weight_transfer_intensity", 0.7)
	collision_bounce = preset.get("collision_bounce", 0.4)
	handbrake_grip_reduction = preset.get("handbrake_grip_reduction", 0.2)
	counter_steer_assist = preset.get("counter_steer_assist", 0.25)

	# Load drivetrain modifier
	drivetrain_modifier = ConfigManager.get_drivetrain_modifier(drive_type)

	# Apply part modifiers (player car only)
	_apply_part_modifiers()

## Load enhanced physics configuration
func _load_enhanced_config() -> void:
	var enhanced_config = ConfigManager.get_enhanced_physics()
	if enhanced_config.is_empty():
		return

	# Configure tire model
	var tire_config = enhanced_config.get("tire_model", {})
	if tire_model:
		tire_model.peak_slip_angle = tire_config.get("peak_slip_angle", 8.0)
		tire_model.falloff_sharpness = tire_config.get("falloff_sharpness", 0.8)
		tire_model.load_sensitivity = tire_config.get("load_sensitivity", 0.7)
		tire_model.grip_coefficient = tire_grip_coefficient

	# Configure weight transfer
	var weight_config = enhanced_config.get("weight_transfer", {})
	if weight_transfer:
		weight_transfer.wheelbase = weight_config.get("wheelbase", 2.5)
		weight_transfer.center_of_gravity_height = weight_config.get("cog_height", 0.5)
		weight_transfer.longitudinal_transfer_rate = weight_config.get("longitudinal_rate", 8.0)
		weight_transfer.lateral_transfer_rate = weight_config.get("lateral_rate", 6.0)

	# Configure collision response
	var collision_config = enhanced_config.get("collision", {})
	if collision_response:
		collision_response.wall_restitution = collision_config.get("wall_restitution", 0.4) * collision_bounce
		collision_response.car_restitution = collision_config.get("car_restitution", 0.6) * collision_bounce
		collision_response.spin_factor = collision_config.get("spin_factor", 0.015)
		collision_response.max_spin_rate = collision_config.get("max_spin_rate", 8.0)

## Handle gear change signal
func _on_gear_changed(new_gear: int, _rpm_percent: float) -> void:
	gear_changed.emit(new_gear)

## Apply part upgrade modifiers to base stats
func _apply_part_modifiers() -> void:
	# Get part modifiers (without damage - we apply damage separately for real-time updates)
	if use_player_upgrades and PlayerProgress:
		part_modifiers = CarModifiers.from_equipped(PlayerProgress.get_all_equipped())
	else:
		part_modifiers = CarModifiers.defaults()

	# Apply part multipliers to get base stats (before damage)
	_base_acceleration = ACCELERATION * part_modifiers.acceleration_mult
	_base_max_speed = MAX_SPEED * part_modifiers.max_speed_mult
	_base_brake_force = BRAKE_FORCE * part_modifiers.brake_mult
	_base_rotation_speed = ROTATION_SPEED * part_modifiers.rotation_mult
	_base_drag_coeff = AIR_DRAG_COEFF * part_modifiers.drag_mult
	FRICTION *= part_modifiers.friction_mult

	# Store base lateral grip
	_base_lateral_grip = drivetrain_modifier.get("lateral_grip", 0.2) * part_modifiers.lateral_grip_mult

	# Now apply current damage state
	_apply_realtime_damage()

## Apply damage modifiers in real-time (called when damage is taken)
func _apply_realtime_damage() -> void:
	var damage_state: CarDamageState = null

	if DamageSystem:
		damage_state = DamageSystem.get_damage_state(self)

	if damage_state and damage_state.has_damage():
		# Apply damage to base stats
		ACCELERATION = _base_acceleration * damage_state.get_effectiveness("engines", "acceleration")
		MAX_SPEED = _base_max_speed * damage_state.get_effectiveness("engines", "max_speed")
		BRAKE_FORCE = _base_brake_force * damage_state.get_effectiveness("brakes", "brake")
		ROTATION_SPEED = _base_rotation_speed * damage_state.get_effectiveness("suspensions", "rotation")
		AIR_DRAG_COEFF = _base_drag_coeff * damage_state.get_effectiveness("spoilers", "drag")

		# Lateral grip affected by tires and suspension
		var tire_grip = damage_state.get_effectiveness("tires", "lateral_grip")
		var susp_grip = damage_state.get_effectiveness("suspensions", "lateral_grip")
		drivetrain_modifier["lateral_grip"] = _base_lateral_grip * tire_grip * susp_grip
	else:
		# No damage - use base stats
		ACCELERATION = _base_acceleration
		MAX_SPEED = _base_max_speed
		BRAKE_FORCE = _base_brake_force
		ROTATION_SPEED = _base_rotation_speed
		AIR_DRAG_COEFF = _base_drag_coeff
		drivetrain_modifier["lateral_grip"] = _base_lateral_grip

## Handle damage taken signal - update stats in real-time
func _on_damage_taken(car: Node, _part: String, _amount: float, _new_health: float) -> void:
	if car != self:
		return
	_apply_realtime_damage()

## Handle part failure - special effects
func _on_part_failed(car: Node, part: String) -> void:
	if car != self:
		return

	_apply_realtime_damage()

	# Emit signals for special failure effects
	match part:
		"tires":
			tire_blowout.emit()
		"engines":
			engine_failed.emit()

## Handle car totaled - disable controls
func _on_car_totaled(car: Node, reason: String) -> void:
	if car != self:
		return

	is_totaled = true
	_totaled_reason = reason
	car_totaled.emit(reason)

## Refresh upgrades (call when player equips new parts)
func refresh_upgrades() -> void:
	apply_tuning(tuning_mode)

# -------------------------
# Physics process
# -------------------------
func _physics_process(delta: float) -> void:
	handle_surface()

	# If totaled, only apply drag to slow down
	if is_totaled:
		_apply_totaled_physics(delta)
		move_and_slide()
		update_speed_display(delta)
		return

	# Get input from controller
	if controller != null:
		current_input = controller.get_input()
	else:
		current_input = CarController.InputState.new()

	if use_enhanced_physics:
		_enhanced_physics_process(delta)
	else:
		handle_input(delta)
		apply_physics(delta)

	handle_drift(delta)
	move_and_slide()
	_check_collision_damage_enhanced()
	update_speed_display(delta)

## Enhanced physics process with all new systems
func _enhanced_physics_process(delta: float) -> void:
	# Note: Sprite is rotated 180° so we use DOWN as base forward direction
	var forward = Vector2.UP.rotated(rotation)
	var right = forward.rotated(PI / 2.0)

	# Update transmission
	var speed = velocity.length()
	transmission.update(speed, current_input.throttle, delta)

	# Calculate current accelerations for weight transfer
	var longitudinal_accel = _get_longitudinal_acceleration()
	var lateral_accel = _get_lateral_acceleration()

	# Update weight transfer
	weight_transfer.update(longitudinal_accel * weight_transfer_intensity,
						   lateral_accel * weight_transfer_intensity, delta)

	# Calculate slip angle
	current_slip_angle = TireModel.get_slip_angle(velocity, forward)

	# Determine if drifting
	is_drifting = abs(current_slip_angle) > 15.0

	# Handle handbrake
	is_handbrake_active = current_input.handbrake > 0.5

	# Calculate grip based on tire model and weight transfer
	var front_grip = tire_model.calculate_grip(current_slip_angle, weight_transfer.get_front_grip())
	var rear_grip = tire_model.calculate_grip(current_slip_angle, weight_transfer.get_rear_grip())

	# Reduce rear grip when handbrake is active
	if is_handbrake_active:
		rear_grip *= handbrake_grip_reduction

	# Average grip for simplified model
	var total_grip = (front_grip + rear_grip) * 0.5 * tire_grip_coefficient

	# Apply acceleration with transmission torque curve
	_apply_enhanced_acceleration(delta, total_grip)

	# Apply enhanced steering with slip angle consideration
	_apply_enhanced_steering(delta, front_grip, rear_grip)

	# Apply physics (friction, drag, grip)
	_apply_enhanced_physics(delta, total_grip)

	# Apply collision-induced spin
	_apply_collision_spin(delta)

	# Counter-steer detection and assist
	_handle_counter_steer(delta)

	# Update audio systems
	_update_audio_systems()

	# Update damage effects with drift state
	_update_drift_effects()

## Get longitudinal acceleration (for weight transfer)
func _get_longitudinal_acceleration() -> float:
	if current_input.throttle > 0.1:
		return current_input.throttle * 0.5  # Accelerating - weight to rear
	elif current_input.brake > 0.1:
		return -current_input.brake * 0.8  # Braking - weight to front
	return 0.0

## Get lateral acceleration (for weight transfer)
func _get_lateral_acceleration() -> float:
	if velocity.length() < 20:
		return 0.0
	var forward = Vector2.UP.rotated(rotation)
	var right = forward.rotated(PI / 2.0)
	var lateral_vel = velocity.dot(right)
	# Estimate lateral G based on speed and turn rate
	return lateral_vel / max(velocity.length(), 1.0) * 2.0

## Apply acceleration with transmission torque
func _apply_enhanced_acceleration(delta: float, grip: float) -> void:
	var forward = Vector2.UP.rotated(rotation)
	var force = Vector2.ZERO

	# Get surface multipliers (default to 1.0 if not available)
	var accel_mult = surface_props.acceleration_multiplier if surface_props else 1.0
	var brake_mult = surface_props.brake_multiplier if surface_props else 1.0

	if current_input.throttle > 0:
		# Simple direct acceleration - bypass transmission complexity
		var accel_force = ACCELERATION * current_input.throttle
		force = forward * accel_force * accel_mult

	elif current_input.brake > 0:
		if is_handbrake_active:
			# Handbrake: lock rear wheels, car rotates
			_apply_handbrake_physics(delta)
		elif velocity.dot(forward) > 10:
			# Normal braking
			var brake_force_val = BRAKE_FORCE * current_input.brake * brake_mult
			velocity -= forward * brake_force_val * delta
		else:
			# Reverse
			force = -forward * (ACCELERATION * 0.6) * current_input.brake * accel_mult

	velocity += force * delta

## Apply handbrake physics (drift initiation)
func _apply_handbrake_physics(delta: float) -> void:
	var forward = Vector2.UP.rotated(rotation)

	# Decelerate
	var enhanced_config = ConfigManager.get_enhanced_physics()
	var handbrake_config = enhanced_config.get("handbrake", {})
	var decel = handbrake_config.get("deceleration", 400.0)
	velocity = velocity.move_toward(Vector2.ZERO, decel * delta)

	# Induce rotation based on steering input
	var spin_boost = handbrake_config.get("spin_boost", 1.5)
	if abs(current_input.steer) > 0.1:
		angular_velocity += current_input.steer * spin_boost * delta * velocity.length() * 0.01

## Apply enhanced steering with slip angle consideration
func _apply_enhanced_steering(delta: float, front_grip: float, rear_grip: float) -> void:
	if velocity.length() < 10:
		return

	var direction = current_input.steer

	# Speed-sensitive steering
	var physics = ConfigManager.get_car_physics()
	var speed_factor = physics.get("steering_speed_factor", 0.7)
	var min_strength = physics.get("steering_min_strength", 0.2)
	var max_strength = physics.get("steering_max_strength", 1.0)
	var steer_strength = clamp(velocity.length() / (MAX_SPEED * speed_factor), min_strength, max_strength)

	# Steering effectiveness reduced when front tires are sliding
	var steering_grip = front_grip * 0.7 + 0.3  # Never completely lose steering

	# Drivetrain steering multiplier
	var steering_mult = drivetrain_modifier.get("steering_mult", 1.0)

	# Calculate rotation change
	var rot_mult = surface_props.rotation_multiplier if surface_props else 1.0
	var rotation_change = direction * ROTATION_SPEED * delta * rot_mult
	rotation_change *= steer_strength * steering_mult * steering_grip

	rotation += rotation_change

## Apply enhanced physics (grip, friction, drag)
func _apply_enhanced_physics(delta: float, grip: float) -> void:
	var forward = Vector2.UP.rotated(rotation)

	# Get surface multipliers (default to 1.0 if not available)
	var friction_mult = surface_props.friction_multiplier if surface_props else 1.0
	var drag_mult = surface_props.drag_multiplier if surface_props else 1.0
	var drift_mult = surface_props.drift_multiplier if surface_props else 1.0
	var speed_mult = surface_props.speed_multiplier if surface_props else 1.0

	# Friction when coasting
	var is_coasting = current_input.throttle <= 0 and current_input.brake <= 0
	if is_coasting:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * friction_mult * delta)

	# Aerodynamic drag
	var drag = velocity * velocity.length() * AIR_DRAG_COEFF * drag_mult
	velocity -= drag * delta

	# Lateral grip (tire model based)
	var lateral = velocity - forward * velocity.dot(forward)
	var lateral_grip_force = lateral * grip * drift_mult

	# Apply lateral grip (reduces sideways movement)
	velocity -= lateral_grip_force * delta * 5.0

	# Additional drivetrain-specific grip
	var base_lateral_grip = drivetrain_modifier.get("lateral_grip", 0.2)
	velocity -= lateral * base_lateral_grip

	# Speed limit
	var max_speed = MAX_SPEED * speed_mult
	if velocity.length() > max_speed:
		velocity = velocity.limit_length(max_speed)

## Apply collision-induced spin
func _apply_collision_spin(delta: float) -> void:
	if collision_response:
		angular_velocity = collision_response.update_spin(delta)

	# Apply angular velocity to rotation
	rotation += angular_velocity * delta

	# Natural angular velocity decay
	angular_velocity = lerp(angular_velocity, 0.0, delta * 3.0)

## Handle counter-steer detection and assist
func _handle_counter_steer(delta: float) -> void:
	if not is_drifting:
		counter_steer_active = false
		return

	var forward = Vector2.UP.rotated(rotation)
	var velocity_angle = velocity.angle()
	var heading_angle = forward.angle()

	# Detect if player is counter-steering (steering opposite to drift direction)
	var drift_direction = sign(angle_difference(heading_angle, velocity_angle))
	var steer_direction = sign(current_input.steer)

	# Counter-steer if steering opposite to drift
	counter_steer_active = (drift_direction != 0 and steer_direction != 0 and
						   drift_direction != steer_direction)

	if counter_steer_active:
		# Reward counter-steering with better recovery
		var enhanced_config = ConfigManager.get_enhanced_physics()
		var cs_config = enhanced_config.get("counter_steer", {})
		var recovery_bonus = cs_config.get("recovery_bonus", 1.2)

		# Help straighten out the car
		var correction = drift_direction * counter_steer_assist * delta
		rotation -= correction

## Apply physics when car is totaled (coast to a stop)
func _apply_totaled_physics(delta: float) -> void:
	# Heavy drag to slow down
	velocity = velocity.move_toward(Vector2.ZERO, 300 * delta)

	# Apply friction
	velocity = velocity.move_toward(Vector2.ZERO, FRICTION * 2.0 * delta)

## Check for collision damage after move_and_slide (original)
func _check_collision_damage() -> void:
	if not DamageSystem:
		return

	var collision_count = get_slide_collision_count()
	for i in collision_count:
		var collision = get_slide_collision(i)
		DamageSystem.process_collision(self, collision)

		# Trigger visual effects for significant collisions
		var impact_speed = velocity.length()
		if impact_speed > 50:  # Only show sparks for notable impacts
			_trigger_collision_effects(collision)

## Enhanced collision damage check with bounce/deflection
func _check_collision_damage_enhanced() -> void:
	if not DamageSystem:
		_check_collision_damage()
		return

	var collision_count = get_slide_collision_count()
	for i in collision_count:
		var collision = get_slide_collision(i)

		# Check if colliding with another car
		var collider = collision.get_collider()
		var is_car_collision = collider and collider.is_in_group("cars")

		# Process damage through DamageSystem
		DamageSystem.process_collision(self, collision)

		# Apply enhanced collision response (bounce/spin)
		if collision_response and use_enhanced_physics:
			var pre_velocity = velocity
			var response = collision_response.process_collision(
				pre_velocity, collision, rotation, is_car_collision
			)

			# Apply bounce velocity
			velocity = response.velocity

			# Apply collision-induced spin
			collision_response.add_spin(response.spin)

			# Trigger visual effects based on severity
			if response.severity > 0.2:
				_trigger_collision_effects(collision)

				# Extra spin for severe impacts
				if response.severity > 0.6:
					angular_velocity += response.spin * 0.5
		else:
			# Fallback to simple collision effects
			var impact_speed = velocity.length()
			if impact_speed > 50:
				_trigger_collision_effects(collision)

## Trigger visual effects for a collision
func _trigger_collision_effects(collision: KinematicCollision2D) -> void:
	var damage_effects = get_node_or_null("DamageEffects")
	if damage_effects and damage_effects.has_method("on_collision"):
		var normal = collision.get_normal()
		var impact_speed = velocity.length()
		damage_effects.on_collision(normal, impact_speed)

# -------------------------
# Input
# -------------------------
func handle_input(delta: float) -> void:
	# Get input from controller
	if controller != null:
		current_input = controller.get_input()
	else:
		current_input = CarController.InputState.new()

	var force = Vector2.ZERO
	var forward = Vector2.UP.rotated(rotation)

	# Get surface multipliers (default to 1.0 if not available)
	var accel_mult = surface_props.acceleration_multiplier if surface_props else 1.0
	var brake_mult = surface_props.brake_multiplier if surface_props else 1.0
	var rot_mult = surface_props.rotation_multiplier if surface_props else 1.0

	if current_input.throttle > 0:
		# Forward acceleration
		force = forward * ACCELERATION * accel_mult * current_input.throttle
	elif current_input.brake > 0:
		if velocity.dot(forward) > 0:
			# Braking when moving forward
			velocity -= forward * BRAKE_FORCE * delta * brake_mult * current_input.brake
		else:
			# Reverse acceleration
			force = -forward * (ACCELERATION * 0.6) * accel_mult * current_input.brake

	velocity += force * delta

	# Steering only if moving
	if velocity.length() > 10:
		var direction := current_input.steer
		var physics = ConfigManager.get_car_physics()
		var speed_factor = physics.get("steering_speed_factor", 0.7)
		var min_strength = physics.get("steering_min_strength", 0.2)
		var max_strength = physics.get("steering_max_strength", 1.0)
		var steer_strength = clamp(velocity.length() / (MAX_SPEED * speed_factor), min_strength, max_strength)

		var steering_mult = drivetrain_modifier.get("steering_mult", 1.0)
		rotation += direction * ROTATION_SPEED * delta * rot_mult * steer_strength * steering_mult

	
# -------------------------
# Physics
# -------------------------
func apply_physics(delta: float) -> void:
	var forward = Vector2.UP.rotated(rotation)

	# Get surface multipliers (default to 1.0 if not available)
	var friction_mult = surface_props.friction_multiplier if surface_props else 1.0
	var drag_mult = surface_props.drag_multiplier if surface_props else 1.0
	var drift_mult = surface_props.drift_multiplier if surface_props else 1.0
	var speed_mult = surface_props.speed_multiplier if surface_props else 1.0

	# Apply friction / rolling resistance (when not accelerating or braking)
	var is_coasting = current_input == null or (current_input.throttle <= 0 and current_input.brake <= 0)
	if is_coasting:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * friction_mult * delta)

	# Apply aerodynamic drag
	var drag = velocity * velocity.length() * AIR_DRAG_COEFF * drag_mult
	velocity -= drag * delta

	# Drift physics
	var lateral = velocity - forward * velocity.dot(forward)
	var physics = ConfigManager.get_car_physics()
	var grip_min = physics.get("lateral_grip_clamp_min", 0.3)
	var grip_max = physics.get("lateral_grip_clamp_max", 1.0)
	var steer_strength = clamp(velocity.length() / MAX_SPEED, grip_min, grip_max)
	velocity -= lateral * drift_mult * steer_strength

	# Extra grip differences by drivetrain (from config)
	var lateral_grip = drivetrain_modifier.get("lateral_grip", 0.2)
	velocity -= lateral * lateral_grip

	# Clamp speed with surface multiplier
	var max_speed = MAX_SPEED * speed_mult
	if velocity.length() > max_speed:
		velocity = velocity.limit_length(max_speed)

# -------------------------
# Visual Effects
# -------------------------

func handle_drift(delta: float) -> void:
	drift_manager.surface_drift_multiplier = surface_props.drift_multiplier
	var steering_input: float = -current_input.steer if current_input != null else 0.0

	var forward = Vector2.UP.rotated(rotation)
	var drift_value = drift_manager.update_drift(delta, velocity, forward, steering_input)

	update_drift_effects(drift_value * 100)
	
func update_drift_effects(drift_value: float) -> void:
	var visuals = ConfigManager.get_visual_settings()
	var particle_threshold = visuals.get("drift_particle_threshold", 60)
	var particle_base = visuals.get("drift_particle_amount_base", 20)
	var particle_scale = visuals.get("drift_particle_amount_scale", 80)
	var tire_threshold = visuals.get("tire_marks_threshold", 100)
	var tire_max_points = visuals.get("tire_marks_max_points", 100)

	# Particle intensity
	drift_particles.emitting = drift_value > particle_threshold
	drift_particles.amount = int(particle_base + (drift_value / 100) * particle_scale)

	# Tire marks
	if drift_value > tire_threshold:
		tire_marks.add_point(tiremarks_pos.global_position)
		if tire_marks.points.size() > tire_max_points:
			tire_marks.remove_point(0)
	else:
		if tire_marks.points.size() > 2:
			# Emit signal with current points
			drift_marks_finished.emit(tire_marks.points)
		tire_marks.clear_points()
		
	## Tire sound volume#
	## Camera shake (optional, if you have a Camera2D node with a shake script)

# -------------------------
# Surfaces
# -------------------------
func handle_surface() -> void:
	current_surface = get_surface_type()
	surface_props = surface_manager.get_surface_properties(current_surface)

func get_surface_type() -> String:
	var cell = tile_map_layer.local_to_map(global_position)
	var tile_data = tile_map_layer.get_cell_tile_data(cell)
	if tile_data and tile_data.has_custom_data("surface"):
		return tile_data.get_custom_data("surface")
	return "road"


# -------------------------
# UI
# -------------------------
func update_speed_display(delta: float) -> void:
	var speed_kmh = velocity.length() * 0.1
	displayed_speed = lerp(displayed_speed, speed_kmh, delta * 5)
	var speed: String = str(int(displayed_speed)) + " km/h"
	update_speed.emit(speed)

# -------------------------
# Controller
# -------------------------
func set_controller(new_controller: CarController) -> void:
	if controller != null:
		controller.on_detached()
	controller = new_controller
	if controller != null:
		controller.on_attached(self)

# -------------------------
# Audio Systems
# -------------------------

## Update procedural audio systems based on current car state
func _update_audio_systems() -> void:
	if not use_procedural_audio:
		return

	var speed = velocity.length()
	var throttle = current_input.throttle if current_input else 0.0

	# Engine audio
	if engine_audio:
		var rpm_percent = 0.0
		if transmission:
			rpm_percent = transmission.get_rpm_percent()
		else:
			# Fallback RPM calculation based on speed
			rpm_percent = clampf(speed / MAX_SPEED, 0.0, 1.0)

		engine_audio.update(rpm_percent, throttle)

		# Start engine audio if not playing
		if not engine_audio.is_playing and speed > 0:
			engine_audio.start()

	# Tire screech audio
	if tire_screech_audio:
		tire_screech_audio.update(current_slip_angle, speed)

		# Start screech audio if not playing
		if not tire_screech_audio.screech_player.playing:
			tire_screech_audio.start()

## Update drift-based visual effects
func _update_drift_effects() -> void:
	var damage_effects = get_node_or_null("DamageEffects")
	if damage_effects and damage_effects.has_method("update_drift_state"):
		damage_effects.update_drift_state(current_slip_angle, velocity.length(), is_drifting)

## Start all audio systems (call when car becomes active)
func start_audio() -> void:
	if engine_audio:
		engine_audio.start()
	if tire_screech_audio:
		tire_screech_audio.start()

## Stop all audio systems (call when car becomes inactive)
func stop_audio() -> void:
	if engine_audio:
		engine_audio.stop()
	if tire_screech_audio:
		tire_screech_audio.stop()

## Set audio master volume for this car
func set_audio_volume(volume: float) -> void:
	if engine_audio:
		engine_audio.set_master_volume(volume)
	if tire_screech_audio:
		tire_screech_audio.set_master_volume(volume)
	if transmission_audio:
		transmission_audio.set_master_volume(volume)

## Get current RPM percent (for HUD display)
func get_rpm_percent() -> float:
	if transmission:
		return transmission.get_rpm_percent()
	return clampf(velocity.length() / MAX_SPEED, 0.0, 1.0)

## Get current gear (for HUD display)
func get_current_gear() -> int:
	if transmission:
		return transmission.current_gear
	return 1

## Get weight transfer data (for HUD display)
func get_weight_transfer_data() -> Dictionary:
	if weight_transfer:
		return {
			"front": weight_transfer.get_front_grip(),
			"rear": weight_transfer.get_rear_grip(),
			"left": 0.5 - weight_transfer.get_current_lateral() * 0.5,
			"right": 0.5 + weight_transfer.get_current_lateral() * 0.5
		}
	return {"front": 0.5, "rear": 0.5, "left": 0.5, "right": 0.5}
