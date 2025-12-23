class_name Car
extends CharacterBody2D

@export_enum("FWD", "RWD", "AWD")
var drive_type: String = "RWD"

# Active tuning preset
@export_enum("arcade", "realistic", "hybrid")
var tuning_mode: String = "hybrid"
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

# -------------------------
# Tuning presets
# -------------------------
const TUNING_PRESETS := {
	"arcade": {
		"ACCELERATION": 500.0,
		"MAX_SPEED": 380.0,
		"FRICTION": 200.0,
		"BRAKE_FORCE": 800.0,
		"ROTATION_SPEED": 3.2,
		"AIR_DRAG_COEFF": 0.0004,
		"DRIFT_THRESHOLD": 70.0,
	},
	"realistic": {
		"ACCELERATION": 300.0,
		"MAX_SPEED": 300.0,
		"FRICTION": 400.0,
		"BRAKE_FORCE": 500.0,
		"ROTATION_SPEED": 2.2,
		"AIR_DRAG_COEFF": 0.0008,
		"DRIFT_THRESHOLD": 120.0,
	},
	"hybrid": {
		"ACCELERATION": 400.0,
		"MAX_SPEED": 340.0,
		"FRICTION": 300.0,
		"BRAKE_FORCE": 600.0,
		"ROTATION_SPEED": 2.6,
		"AIR_DRAG_COEFF": 0.0006,
		"DRIFT_THRESHOLD": 100.0,
	}
}

# -------------------------
# Lifecycle
# -------------------------
func _ready() -> void:
	apply_tuning(tuning_mode)
	
	drift_manager = DriftManager.new()
	add_child(drift_manager)

# Apply preset values
func apply_tuning(mode: String) -> void:
	if not TUNING_PRESETS.has(mode):
		push_warning("Unknown tuning mode: %s" % mode)
		return

	var preset = TUNING_PRESETS[mode]
	ACCELERATION = preset["ACCELERATION"]
	MAX_SPEED = preset["MAX_SPEED"]
	FRICTION = preset["FRICTION"]
	BRAKE_FORCE = preset["BRAKE_FORCE"]
	ROTATION_SPEED = preset["ROTATION_SPEED"]
	AIR_DRAG_COEFF = preset["AIR_DRAG_COEFF"]
	DRIFT_THRESHOLD = preset["DRIFT_THRESHOLD"]

	print("Applied tuning preset:", mode)

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
	var force = Vector2.ZERO
	var forward = Vector2.UP.rotated(rotation)

	if Input.is_action_pressed("ui_up"):
		# Forward acceleration
		force = forward * ACCELERATION * surface_props.acceleration_multiplier
	elif Input.is_action_pressed("ui_down"):
		if velocity.dot(forward) > 0:
			# Braking when moving forward
			velocity -= forward * BRAKE_FORCE * delta * surface_props.brake_multiplier
		else:
			# Reverse acceleration
			force = -forward * (ACCELERATION * 0.6) * surface_props.acceleration_multiplier

	velocity += force * delta

	# Steering only if moving
	if velocity.length() > 10:
		var direction := 0.0
		if Input.is_action_pressed("ui_left"):
			direction -= 1
		if Input.is_action_pressed("ui_right"):
			direction += 1

		var steer_strength = clamp(velocity.length() / (MAX_SPEED * 0.7), 0.2, 1.0)

		match drive_type:
			"FWD":
				rotation += direction * ROTATION_SPEED * delta * surface_props.rotation_multiplier * steer_strength
			"RWD":
				rotation += direction * ROTATION_SPEED * delta * surface_props.rotation_multiplier * steer_strength * 1.2
			"AWD":
				rotation += direction * ROTATION_SPEED * delta * surface_props.rotation_multiplier * steer_strength * 0.8

	
# -------------------------
# Physics
# -------------------------
func apply_physics(delta: float) -> void:
	var forward = Vector2.UP.rotated(rotation)

	# Apply friction / rolling resistance
	if not Input.is_action_pressed("ui_up") and not Input.is_action_pressed("ui_down"):
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * surface_props.friction_multiplier * delta)

	# Apply aerodynamic drag
	var drag = velocity * velocity.length() * AIR_DRAG_COEFF * surface_props.drag_multiplier
	velocity -= drag * delta


	# Drift physics
	var lateral = velocity - forward * velocity.dot(forward)
	var steer_strength = clamp(velocity.length() / MAX_SPEED, 0.3, 1.0)
	velocity -= lateral * surface_props.drift_multiplier * steer_strength

	# Extra grip differences by drivetrain
	match drive_type:
		"FWD":
			velocity -= lateral * 0.4
		"AWD":
			velocity -= lateral * 0.2
		"RWD":
			velocity -= lateral * 0.05

	# Clamp speed with surface multiplier
	var max_speed = MAX_SPEED * surface_props.speed_multiplier
	if velocity.length() > max_speed:
		velocity = velocity.limit_length(max_speed)

# -------------------------
# Visual Effects
# -------------------------

func handle_drift(delta: float) -> void:
	drift_manager.surface_drift_multiplier = surface_props.drift_multiplier
	var steering_input: float = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")

	var forward = Vector2.UP.rotated(rotation)
	var drift_value = drift_manager.update_drift(delta, velocity, forward, steering_input)
	#var drift_value = drift_manager.update_drift(delta, velocity, forward)

	update_drift_effects(drift_value * 100)
	
func update_drift_effects(drift_value: float) -> void:
	# Particle intensity
	
	drift_particles.emitting = drift_value > 60
	drift_particles.amount = int(20 + (drift_value / 100) * 80)
	print(drift_value)
	# Tire marks
	if drift_value > 100:
		tire_marks.add_point(tiremarks_pos.global_position)
		if tire_marks.points.size() > 100:
			tire_marks.remove_point(0)
	else:
		if tire_marks.points.size() > 2:
			# Emit signal with current points
			drift_marks_finished.emit(tire_marks.points)
		tire_marks.clear_points()
		pass
		
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
