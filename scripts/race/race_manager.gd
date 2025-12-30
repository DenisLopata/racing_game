extends Node
## Singleton that manages race state, cars, and race flow
## Registered as Autoload "RaceManager" in Project Settings

enum RaceState {
	PRE_RACE,    # Before countdown starts
	COUNTDOWN,   # 3-2-1-GO countdown
	RACING,      # Race in progress
	FINISHED     # Race completed
}

# Signals
signal race_state_changed(new_state: RaceState)
signal countdown_tick(seconds_remaining: int)
signal race_started()
signal race_finished(results: Array)
signal car_registered(car: Car, car_id: int)
signal car_finished(car: Car, position: int, total_time: float)

# Race configuration
@export var total_laps: int = 3
@export var countdown_seconds: int = 3

# Race state
var state: RaceState = RaceState.PRE_RACE
var registered_cars: Array[Car] = []
var car_data: Dictionary = {}  # car_id -> {laps, lap_times, finished, finish_time, position}
var race_start_time: float = 0.0
var next_car_id: int = 0

# Countdown
var countdown_timer: Timer
var current_countdown: int = 0

func _ready() -> void:
	# Create countdown timer
	countdown_timer = Timer.new()
	countdown_timer.one_shot = false
	countdown_timer.wait_time = 1.0
	countdown_timer.timeout.connect(_on_countdown_timer_timeout)
	add_child(countdown_timer)

## Register a car to participate in the race
func register_car(car: Car) -> int:
	var car_id = next_car_id
	next_car_id += 1

	car.car_id = car_id
	registered_cars.append(car)

	car_data[car_id] = {
		"car": car,
		"laps": 0,
		"lap_times": [],
		"current_lap_start": 0.0,
		"finished": false,
		"finish_time": 0.0,
		"finish_position": 0,
		"checkpoints_passed": 0,
		"last_checkpoint": -1
	}

	car_registered.emit(car, car_id)
	return car_id

## Unregister a car from the race
func unregister_car(car: Car) -> void:
	if car in registered_cars:
		registered_cars.erase(car)
		car_data.erase(car.car_id)

## Start the countdown sequence
func start_countdown() -> void:
	if state != RaceState.PRE_RACE:
		return

	state = RaceState.COUNTDOWN
	race_state_changed.emit(state)

	current_countdown = countdown_seconds
	countdown_tick.emit(current_countdown)
	countdown_timer.start()

## Called when countdown timer ticks
func _on_countdown_timer_timeout() -> void:
	current_countdown -= 1

	if current_countdown > 0:
		countdown_tick.emit(current_countdown)
	elif current_countdown == 0:
		countdown_tick.emit(0)  # "GO!"
	else:
		# Countdown finished, start race
		countdown_timer.stop()
		_start_race()

## Actually start the race
func _start_race() -> void:
	state = RaceState.RACING
	race_start_time = Time.get_ticks_msec() / 1000.0

	# Initialize lap timing for all cars
	for car_id in car_data.keys():
		car_data[car_id]["current_lap_start"] = race_start_time
		car_data[car_id]["laps"] = 0

	race_state_changed.emit(state)
	race_started.emit()

## Called when a car crosses the start/finish line
func on_car_crossed_line(car: Car) -> void:
	if state != RaceState.RACING:
		return

	var car_id = car.car_id
	if car_id not in car_data:
		return

	var data = car_data[car_id]
	if data["finished"]:
		return

	# Record lap time
	var current_time = Time.get_ticks_msec() / 1000.0
	var lap_time = current_time - data["current_lap_start"]

	data["lap_times"].append(lap_time)
	data["laps"] += 1
	data["current_lap_start"] = current_time
	data["checkpoints_passed"] = 0
	data["last_checkpoint"] = -1

	# Check if car finished the race
	if data["laps"] >= total_laps:
		_car_finished(car, current_time)

## Called when a car passes a checkpoint
func on_car_checkpoint(car: Car, checkpoint_index: int) -> void:
	if state != RaceState.RACING:
		return

	var car_id = car.car_id
	if car_id not in car_data:
		return

	var data = car_data[car_id]
	if data["finished"]:
		return

	# Only count if this is the next checkpoint in sequence
	if checkpoint_index == data["last_checkpoint"] + 1:
		data["checkpoints_passed"] += 1
		data["last_checkpoint"] = checkpoint_index

## Mark a car as finished
func _car_finished(car: Car, finish_time: float) -> void:
	var car_id = car.car_id
	var data = car_data[car_id]

	data["finished"] = true
	data["finish_time"] = finish_time - race_start_time

	# Calculate position (how many cars finished before this one)
	var position = 1
	for other_id in car_data.keys():
		if other_id != car_id and car_data[other_id]["finished"]:
			position += 1

	data["finish_position"] = position
	car_finished.emit(car, position, data["finish_time"])

	# Check if all cars finished
	_check_race_complete()

## Check if all cars have finished
func _check_race_complete() -> void:
	for car_id in car_data.keys():
		if not car_data[car_id]["finished"]:
			return

	# All cars finished
	_finish_race()

## End the race and compile results
func _finish_race() -> void:
	state = RaceState.FINISHED
	race_state_changed.emit(state)

	var results = get_race_results()
	race_finished.emit(results)

## Force finish the race (e.g., when leader finishes)
func force_finish_race() -> void:
	if state != RaceState.RACING:
		return

	var current_time = Time.get_ticks_msec() / 1000.0

	# Mark unfinished cars as DNF
	var position = 1
	for car_id in car_data.keys():
		if car_data[car_id]["finished"]:
			position = max(position, car_data[car_id]["finish_position"] + 1)

	for car_id in car_data.keys():
		if not car_data[car_id]["finished"]:
			car_data[car_id]["finished"] = true
			car_data[car_id]["finish_time"] = current_time - race_start_time
			car_data[car_id]["finish_position"] = position
			position += 1

	_finish_race()

## Get sorted race results
func get_race_results() -> Array:
	var results = []
	for car_id in car_data.keys():
		var data = car_data[car_id]
		results.append({
			"car_id": car_id,
			"car": data["car"],
			"position": data["finish_position"],
			"total_time": data["finish_time"],
			"laps": data["laps"],
			"lap_times": data["lap_times"],
			"best_lap": data["lap_times"].min() if data["lap_times"].size() > 0 else 0.0
		})

	results.sort_custom(func(a, b): return a["position"] < b["position"])
	return results

## Get current positions during race
func get_current_positions(total_checkpoints: int = 1) -> Array:
	var positions = []

	for car_id in car_data.keys():
		var data = car_data[car_id]
		var progress = data["laps"] + (float(data["checkpoints_passed"]) / max(total_checkpoints, 1))

		positions.append({
			"car_id": car_id,
			"car": data["car"],
			"progress": progress,
			"laps": data["laps"],
			"finished": data["finished"]
		})

	# Sort by progress (descending), finished cars first
	positions.sort_custom(func(a, b):
		if a["finished"] != b["finished"]:
			return a["finished"]  # Finished cars first
		return a["progress"] > b["progress"]
	)

	# Assign positions
	for i in positions.size():
		positions[i]["position"] = i + 1

	return positions

## Get a car's current position
func get_car_position(car: Car, total_checkpoints: int = 1) -> int:
	var positions = get_current_positions(total_checkpoints)
	for pos_data in positions:
		if pos_data["car_id"] == car.car_id:
			return pos_data["position"]
	return -1

## Get lap data for a specific car
func get_car_lap_data(car_id: int) -> Dictionary:
	if car_id in car_data:
		return car_data[car_id]
	return {}

## Reset race to pre-race state (keeps registered cars)
func reset_race() -> void:
	state = RaceState.PRE_RACE
	race_start_time = 0.0
	countdown_timer.stop()

	for car_id in car_data.keys():
		car_data[car_id]["laps"] = 0
		car_data[car_id]["lap_times"] = []
		car_data[car_id]["current_lap_start"] = 0.0
		car_data[car_id]["finished"] = false
		car_data[car_id]["finish_time"] = 0.0
		car_data[car_id]["finish_position"] = 0
		car_data[car_id]["checkpoints_passed"] = 0
		car_data[car_id]["last_checkpoint"] = -1

	race_state_changed.emit(state)

## Full reset for scene reload - clears all state
func full_reset() -> void:
	state = RaceState.PRE_RACE
	race_start_time = 0.0
	countdown_timer.stop()
	current_countdown = 0
	registered_cars.clear()
	car_data.clear()
	next_car_id = 0

## Check if race is active
func is_racing() -> bool:
	return state == RaceState.RACING
