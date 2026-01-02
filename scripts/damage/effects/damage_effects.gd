class_name DamageEffects
extends Node2D
## Controls visual and audio damage effects on a car (smoke, sparks, sounds)
## Attach as child of Car node

# Effect nodes - use @onready with $NodePath
@onready var engine_smoke: GPUParticles2D = $EngineSmoke
@onready var collision_sparks: GPUParticles2D = $CollisionSparks
@onready var damage_audio: DamageAudio = $DamageAudio
@onready var tire_smoke: GPUParticles2D = $TireSmoke
@onready var engine_fire: GPUParticles2D = $EngineFire

# Reference to parent car
var _car: Node = null
var _car_sprite: Sprite2D = null

# Blowout spin state
var _tire_blowout_active: bool = false
var _blowout_spin_speed: float = 0.0
var _engine_fire_active: bool = false

# Smoke intensity tracking
var _target_smoke_amount: int = 0
var _current_smoke_amount: float = 0.0

# Spark cooldown to prevent spam
var _spark_cooldown: float = 0.0
const SPARK_COOLDOWN_TIME: float = 0.15

# Drift tire smoke tracking
var _drift_smoke_intensity: float = 0.0
var _is_drifting: bool = false
var _drift_slip_angle: float = 0.0
var _drift_speed: float = 0.0

# Drift smoke thresholds
const DRIFT_MIN_SLIP_ANGLE: float = 10.0
const DRIFT_MAX_SLIP_ANGLE: float = 45.0
const DRIFT_MIN_SPEED: float = 40.0

func _ready() -> void:
	_car = get_parent()
	_car_sprite = _car.get_node_or_null("Sprite2D")

	# Connect to damage system signals
	_connect_damage_signals()

	# Connect to car failure signals
	if _car.has_signal("tire_blowout"):
		_car.tire_blowout.connect(_on_tire_blowout)
	if _car.has_signal("engine_failed"):
		_car.engine_failed.connect(_on_engine_failed)

	# Initialize smoke state from current damage
	call_deferred("refresh_from_damage_state")

func _process(delta: float) -> void:
	_update_smoke(delta)
	_update_spark_cooldown(delta)
	_update_blowout_spin(delta)
	_update_engine_fire(delta)
	_update_drift_smoke(delta)

## Connect to DamageSystem signals
func _connect_damage_signals() -> void:
	if DamageSystem:
		DamageSystem.damage_taken.connect(_on_damage_taken)
		DamageSystem.part_failed.connect(_on_part_failed)

## Handle damage taken - trigger sparks and sounds
func _on_damage_taken(car: Node, part: String, amount: float, new_health: float) -> void:
	if car != _car:
		return

	# Trigger sparks on significant damage
	if amount > 0.05:
		trigger_sparks()
		# Play impact sound based on damage amount
		if damage_audio:
			var severity = clampf(amount * 3.0, 0.2, 1.0)
			damage_audio.play_impact_sound(severity)

	# Update smoke and audio for engine damage
	if part == "engines":
		update_engine_smoke(new_health)
		if damage_audio:
			damage_audio.set_engine_health(new_health)

## Handle part failure - big effect with sound
func _on_part_failed(car: Node, part: String) -> void:
	if car != _car:
		return

	# Big spark burst on part failure
	trigger_sparks(2.0)

	# Play failure sound
	if damage_audio:
		damage_audio.play_part_failure_sound()

	# Heavy smoke for engine failure
	if part == "engines":
		update_engine_smoke(0.0)
		if damage_audio:
			damage_audio.set_engine_health(0.0)

## Trigger spark effect at collision point
func trigger_sparks(intensity: float = 1.0) -> void:
	if not collision_sparks or _spark_cooldown > 0:
		return

	# Adjust spark amount based on intensity
	var base_amount = collision_sparks.amount
	collision_sparks.amount = int(base_amount * intensity)

	# Restart the one-shot particles
	collision_sparks.restart()

	# Reset amount after emission starts
	collision_sparks.amount = base_amount
	_spark_cooldown = SPARK_COOLDOWN_TIME

## Trigger sparks at a specific position (relative to car)
func trigger_sparks_at(local_position: Vector2, intensity: float = 1.0) -> void:
	if not collision_sparks or _spark_cooldown > 0:
		return

	collision_sparks.position = local_position
	trigger_sparks(intensity)

## Update engine smoke based on engine health
func update_engine_smoke(engine_health: float) -> void:
	if not engine_smoke:
		return

	# Start smoking when engine health drops below 50%
	if engine_health < 0.5:
		# Scale smoke intensity inversely with health
		# At 50% health: light smoke, at 0%: heavy smoke
		var damage_factor = 1.0 - (engine_health / 0.5)
		_target_smoke_amount = int(5 + damage_factor * 20)  # 5-25 particles
		engine_smoke.emitting = true
	else:
		_target_smoke_amount = 0
		engine_smoke.emitting = false

## Smoothly update smoke amount
func _update_smoke(delta: float) -> void:
	if not engine_smoke:
		return

	# Lerp towards target
	_current_smoke_amount = lerpf(_current_smoke_amount, float(_target_smoke_amount), delta * 3.0)
	engine_smoke.amount = int(_current_smoke_amount)

	# Stop emitting if amount is very low
	if _current_smoke_amount < 1.0 and _target_smoke_amount == 0:
		engine_smoke.emitting = false

## Update spark cooldown
func _update_spark_cooldown(delta: float) -> void:
	if _spark_cooldown > 0:
		_spark_cooldown -= delta

## Called when car takes collision - position sparks at impact point and play sound
func on_collision(impact_normal: Vector2, impact_speed: float) -> void:
	# Position sparks at the edge of the car in the collision direction
	if collision_sparks:
		var spark_offset = -impact_normal * 16  # Offset towards collision point
		collision_sparks.position = spark_offset

	# Intensity based on speed
	var intensity = clampf(impact_speed / 300.0, 0.3, 2.0)
	trigger_sparks(intensity)

	# Play impact sound (lower threshold for sound than damage)
	if damage_audio and impact_speed > 80:
		var severity = clampf((impact_speed - 80) / 250.0, 0.1, 1.0)
		damage_audio.play_impact_sound(severity)

## Force update from current damage state
func refresh_from_damage_state() -> void:
	if not _car or not DamageSystem:
		return

	var damage_state = DamageSystem.get_damage_state(_car)
	if damage_state:
		var engine_health = damage_state.get_part_health("engines")
		update_engine_smoke(engine_health)
		if damage_audio:
			damage_audio.set_engine_health(engine_health)

## Handle tire blowout - start spinning and tire smoke
func _on_tire_blowout() -> void:
	_tire_blowout_active = true
	_blowout_spin_speed = 8.0  # Initial spin speed (radians/sec)

	# Start tire smoke
	if tire_smoke:
		tire_smoke.emitting = true

	# Play a failure sound
	if damage_audio:
		damage_audio.play_part_failure_sound()

## Handle engine failure - start fire effect
func _on_engine_failed() -> void:
	_engine_fire_active = true

	# Start engine fire
	if engine_fire:
		engine_fire.emitting = true

	# Increase smoke dramatically
	_target_smoke_amount = 30
	if engine_smoke:
		engine_smoke.emitting = true

	# Play failure sound
	if damage_audio:
		damage_audio.play_part_failure_sound()

## Update tire blowout spin effect
func _update_blowout_spin(delta: float) -> void:
	if not _tire_blowout_active:
		return

	# Apply spin to the car sprite for visual effect
	if _car_sprite and _blowout_spin_speed > 0.5:
		# Rotate the sprite slightly to show loss of control
		_car_sprite.rotation += _blowout_spin_speed * delta * 0.3

		# Decay spin speed over time
		_blowout_spin_speed = lerpf(_blowout_spin_speed, 0.0, delta * 0.8)
	elif _blowout_spin_speed <= 0.5:
		# Stop spinning, keep tire smoke going
		_blowout_spin_speed = 0.0

		# Reset sprite rotation after spin ends
		if _car_sprite:
			_car_sprite.rotation = lerpf(_car_sprite.rotation, 0.0, delta * 2.0)

## Update engine fire effect
func _update_engine_fire(delta: float) -> void:
	if not _engine_fire_active or not engine_fire:
		return

	# Fire flickers - vary particle amount
	var flicker = sin(Time.get_ticks_msec() * 0.01) * 0.3 + 0.7
	engine_fire.amount = int(20 * flicker)

## Stop all blowout/fire effects (call when car is repaired or race ends)
func stop_failure_effects() -> void:
	_tire_blowout_active = false
	_engine_fire_active = false
	_blowout_spin_speed = 0.0

	if tire_smoke:
		tire_smoke.emitting = false
	if engine_fire:
		engine_fire.emitting = false
	if _car_sprite:
		_car_sprite.rotation = 0.0

# =============================================================================
# Drift Tire Smoke System
# =============================================================================

## Update drift state from car physics
func update_drift_state(slip_angle: float, speed: float, is_drifting: bool) -> void:
	_drift_slip_angle = abs(slip_angle)
	_drift_speed = abs(speed)
	_is_drifting = is_drifting

## Update drift tire smoke based on current drift state
func _update_drift_smoke(delta: float) -> void:
	if not tire_smoke or _tire_blowout_active:
		return  # Don't override blowout smoke

	# Calculate target drift smoke intensity
	var target_intensity: float = 0.0

	if _drift_slip_angle > DRIFT_MIN_SLIP_ANGLE and _drift_speed > DRIFT_MIN_SPEED:
		# Calculate slip angle factor (0.0 to 1.0)
		var slip_factor = clampf(
			(_drift_slip_angle - DRIFT_MIN_SLIP_ANGLE) / (DRIFT_MAX_SLIP_ANGLE - DRIFT_MIN_SLIP_ANGLE),
			0.0, 1.0
		)

		# Calculate speed factor (higher speed = more smoke)
		var speed_factor = clampf((_drift_speed - DRIFT_MIN_SPEED) / 150.0, 0.3, 1.0)

		# Combine factors
		target_intensity = slip_factor * speed_factor

	# Smooth transition
	_drift_smoke_intensity = lerpf(_drift_smoke_intensity, target_intensity, delta * 6.0)

	# Update tire smoke particles
	if _drift_smoke_intensity > 0.05:
		# Scale particle amount based on intensity (5-30 particles)
		var particle_amount = int(5 + _drift_smoke_intensity * 25)
		tire_smoke.amount = particle_amount

		# Adjust smoke color based on intensity (darker = more intense drift)
		var smoke_color = Color(
			0.5 - _drift_smoke_intensity * 0.2,  # Darker gray
			0.5 - _drift_smoke_intensity * 0.2,
			0.5 - _drift_smoke_intensity * 0.2,
			0.4 + _drift_smoke_intensity * 0.3   # More opaque
		)

		var material = tire_smoke.process_material as ParticleProcessMaterial
		if material:
			material.color = smoke_color

		# Position smoke at rear of car
		tire_smoke.position = Vector2(0, 12)  # Offset to rear wheels

		tire_smoke.emitting = true
	else:
		tire_smoke.emitting = false

## Get current drift smoke intensity (0.0 to 1.0)
func get_drift_smoke_intensity() -> float:
	return _drift_smoke_intensity
