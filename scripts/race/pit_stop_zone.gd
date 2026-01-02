class_name PitStopZone
extends Area2D
## Pit stop area where cars can repair damage during a race
## Repairs cost time, not money

## Signals
signal car_entered_pit(car: Car)
signal car_exited_pit(car: Car)
signal repair_progress(car: Car, progress: float, part: String)
signal repair_complete(car: Car)

## Pit stop configuration
@export var pit_speed_limit: float = 80.0  # Max speed in pit lane
@export var repair_rate: float = 0.2  # Health restored per second per part
@export var simultaneous_repairs: int = 1  # How many parts repair at once

# Cars currently in pit
var _cars_in_pit: Dictionary = {}  # car -> {repair_queue: Array, current_repair: String, original_max_speed: float}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 1  # Detect cars on layer 1

func _process(delta: float) -> void:
	_process_repairs(delta)

## Handle car entering pit
func _on_body_entered(body: Node) -> void:
	if body is Car:
		var car = body as Car
		_start_pit_stop(car)

## Handle car exiting pit
func _on_body_exited(body: Node) -> void:
	if body is Car:
		var car = body as Car
		_end_pit_stop(car)

## Start pit stop for a car
func _start_pit_stop(car: Car) -> void:
	if car in _cars_in_pit:
		return

	# Store original speed and set pit speed limit
	var original_max = car.MAX_SPEED
	car.MAX_SPEED = pit_speed_limit

	# Build repair queue from damaged parts
	var repair_queue: Array[String] = []
	if DamageSystem:
		var damage_state = DamageSystem.get_damage_state(car)
		if damage_state:
			# Queue damaged parts (most damaged first)
			var parts_with_damage: Array = []
			for part in damage_state.part_health.keys():
				var health = damage_state.part_health[part]
				if health < 1.0:
					parts_with_damage.append({"part": part, "health": health})

			# Sort by damage (lowest health first)
			parts_with_damage.sort_custom(func(a, b): return a["health"] < b["health"])

			for pd in parts_with_damage:
				repair_queue.append(pd["part"])

	_cars_in_pit[car] = {
		"repair_queue": repair_queue,
		"current_repair": "",
		"original_max_speed": original_max,
		"repair_progress": 0.0
	}

	# Start repairing first part
	if repair_queue.size() > 0:
		_cars_in_pit[car]["current_repair"] = repair_queue[0]

	car_entered_pit.emit(car)

## End pit stop for a car
func _end_pit_stop(car: Car) -> void:
	if car not in _cars_in_pit:
		return

	var data = _cars_in_pit[car]

	# Restore original max speed
	car.MAX_SPEED = data["original_max_speed"]

	# Re-apply damage to stats (in case partially repaired)
	if car.has_method("_apply_realtime_damage"):
		car._apply_realtime_damage()

	_cars_in_pit.erase(car)
	car_exited_pit.emit(car)

## Process repairs for all cars in pit
func _process_repairs(delta: float) -> void:
	if not DamageSystem:
		return

	for car in _cars_in_pit.keys():
		var data = _cars_in_pit[car]
		var repair_queue: Array = data["repair_queue"]
		var current_part: String = data["current_repair"]

		if current_part.is_empty():
			# No repairs needed
			continue

		var damage_state = DamageSystem.get_damage_state(car)
		if not damage_state:
			continue

		# Apply repair
		var current_health = damage_state.get_part_health(current_part)
		var new_health = minf(current_health + repair_rate * delta, 1.0)
		damage_state.set_part_health(current_part, new_health)

		# Calculate overall repair progress for this part
		var part_progress = new_health

		# Emit progress signal
		repair_progress.emit(car, part_progress, current_part)

		# Check if part is fully repaired
		if new_health >= 1.0:
			# Remove from queue
			repair_queue.erase(current_part)
			data["repair_queue"] = repair_queue

			# Stop any failure effects for this part
			_stop_failure_effects_for_part(car, current_part)

			# Start next repair or finish
			if repair_queue.size() > 0:
				data["current_repair"] = repair_queue[0]
			else:
				data["current_repair"] = ""
				repair_complete.emit(car)

		# Update car stats in real-time as repairs happen
		if car.has_method("_apply_realtime_damage"):
			car._apply_realtime_damage()

## Stop failure effects when a part is repaired
func _stop_failure_effects_for_part(car: Car, part: String) -> void:
	var damage_effects = car.get_node_or_null("DamageEffects")
	if not damage_effects:
		return

	match part:
		"tires":
			if damage_effects.has_method("stop_failure_effects"):
				# Reset tire blowout state
				damage_effects._tire_blowout_active = false
				if damage_effects.tire_smoke:
					damage_effects.tire_smoke.emitting = false
		"engines":
			if damage_effects.has_method("stop_failure_effects"):
				# Reset engine fire state
				damage_effects._engine_fire_active = false
				if damage_effects.engine_fire:
					damage_effects.engine_fire.emitting = false
				damage_effects._target_smoke_amount = 0

## Get repair status for a car
func get_repair_status(car: Car) -> Dictionary:
	if car not in _cars_in_pit:
		return {}

	var data = _cars_in_pit[car]
	return {
		"in_pit": true,
		"current_part": data["current_repair"],
		"parts_remaining": data["repair_queue"].size()
	}

## Check if a car is in the pit
func is_car_in_pit(car: Car) -> bool:
	return car in _cars_in_pit

## Force a car to exit pit (e.g., race ended)
func force_exit(car: Car) -> void:
	if car in _cars_in_pit:
		_end_pit_stop(car)
