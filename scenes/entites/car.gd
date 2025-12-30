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
# Core variables (will be set from tuning dictionary)
var ACCELERATION: float
var MAX_SPEED: float
var FRICTION: float
var BRAKE_FORCE: float
var ROTATION_SPEED: float
var AIR_DRAG_COEFF: float
var DRIFT_THRESHOLD: float

signal drift_marks_finished(points: PackedVector2Array)
signal update_speed(current_speed: String)

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
	apply_tuning(tuning_mode)
	
	drift_manager = DriftManager.new()
	add_child(drift_manager)

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

	# Load drivetrain modifier
	drivetrain_modifier = ConfigManager.get_drivetrain_modifier(drive_type)

	# Apply part modifiers (player car only)
	_apply_part_modifiers()

## Apply part upgrade modifiers to base stats
func _apply_part_modifiers() -> void:
	if not use_player_upgrades:
		part_modifiers = CarModifiers.defaults()
		return

	# Get modifiers from player's equipped parts
	if PlayerProgress:
		part_modifiers = CarModifiers.from_equipped(PlayerProgress.get_all_equipped())
	else:
		part_modifiers = CarModifiers.defaults()

	# Apply multipliers to base stats
	ACCELERATION *= part_modifiers.acceleration_mult
	MAX_SPEED *= part_modifiers.max_speed_mult
	BRAKE_FORCE *= part_modifiers.brake_mult
	ROTATION_SPEED *= part_modifiers.rotation_mult
	AIR_DRAG_COEFF *= part_modifiers.drag_mult
	FRICTION *= part_modifiers.friction_mult

	# Apply lateral grip modifier to drivetrain
	var base_lateral = drivetrain_modifier.get("lateral_grip", 0.2)
	drivetrain_modifier["lateral_grip"] = base_lateral * part_modifiers.lateral_grip_mult

## Refresh upgrades (call when player equips new parts)
func refresh_upgrades() -> void:
	apply_tuning(tuning_mode)

# -------------------------
# Physics process
# -------------------------
func _physics_process(delta: float) -> void:
	handle_surface()
	handle_input(delta)
	apply_physics(delta)
	handle_drift(delta)
	move_and_slide()
	update_speed_display(delta)

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

	if current_input.throttle > 0:
		# Forward acceleration
		force = forward * ACCELERATION * surface_props.acceleration_multiplier * current_input.throttle
	elif current_input.brake > 0:
		if velocity.dot(forward) > 0:
			# Braking when moving forward
			velocity -= forward * BRAKE_FORCE * delta * surface_props.brake_multiplier * current_input.brake
		else:
			# Reverse acceleration
			force = -forward * (ACCELERATION * 0.6) * surface_props.acceleration_multiplier * current_input.brake

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
		rotation += direction * ROTATION_SPEED * delta * surface_props.rotation_multiplier * steer_strength * steering_mult

	
# -------------------------
# Physics
# -------------------------
func apply_physics(delta: float) -> void:
	var forward = Vector2.UP.rotated(rotation)

	# Apply friction / rolling resistance (when not accelerating or braking)
	var is_coasting = current_input == null or (current_input.throttle <= 0 and current_input.brake <= 0)
	if is_coasting:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * surface_props.friction_multiplier * delta)

	# Apply aerodynamic drag
	var drag = velocity * velocity.length() * AIR_DRAG_COEFF * surface_props.drag_multiplier
	velocity -= drag * delta


	# Drift physics
	var lateral = velocity - forward * velocity.dot(forward)
	var physics = ConfigManager.get_car_physics()
	var grip_min = physics.get("lateral_grip_clamp_min", 0.3)
	var grip_max = physics.get("lateral_grip_clamp_max", 1.0)
	var steer_strength = clamp(velocity.length() / MAX_SPEED, grip_min, grip_max)
	velocity -= lateral * surface_props.drift_multiplier * steer_strength

	# Extra grip differences by drivetrain (from config)
	var lateral_grip = drivetrain_modifier.get("lateral_grip", 0.2)
	velocity -= lateral * lateral_grip

	# Clamp speed with surface multiplier
	var max_speed = MAX_SPEED * surface_props.speed_multiplier
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
