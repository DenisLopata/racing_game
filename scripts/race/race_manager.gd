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
signal car_dnf(car: Car, reason: String)

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

	# Connect to damage system for DNF events
	if DamageSystem:
		DamageSystem.car_totaled.connect(_on_car_totaled)

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
		"last_checkpoint": -1,
		"dnf": false,
		"dnf_reason": ""
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
		car_data[car_id]["dnf"] = false
		car_data[car_id]["dnf_reason"] = ""

	# Start damage tracking for all cars
	if DamageSystem:
		for car in registered_cars:
			DamageSystem.start_race_tracking(car)

	race_state_changed.emit(state)
	race_started.emit()

## Called when a car crosses the start/finish line
## total_checkpoints: number of checkpoints on track (0 = no validation)
func on_car_crossed_line(car: Car, total_checkpoints: int = 0) -> void:
	if state != RaceState.RACING:
		return

	var car_id = car.car_id
	if car_id not in car_data:
		return

	var data = car_data[car_id]
	if data["finished"]:
		return

	# VALIDATION: Require checkpoints to be passed (if track has checkpoints)
	if total_checkpoints > 0:
		if data["checkpoints_passed"] < total_checkpoints:
			# Invalid lap - didn't complete the circuit
			return

	# Record lap time (lap is valid)
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

	# Sync player damage to progress
	_sync_player_damage()

	# Record statistics for player
	_record_player_stats()

	var results = get_race_results()
	race_finished.emit(results)

## Record player statistics after race
func _record_player_stats() -> void:
	if not PlayerProgress:
		return

	# Find the player car and their result
	for car in registered_cars:
		if car.get("use_player_upgrades"):
			var data = car_data.get(car.car_id, {})
			if data.is_empty():
				continue

			# Get track ID
			var track_id = "unknown"
			if GameSettings:
				if GameSettings.is_procedural_track:
					track_id = "procedural_%d" % GameSettings.procedural_seed
				else:
					track_id = GameSettings.selected_track

			# Calculate damage taken this race
			var damage_taken: float = 0.0
			var damage_percent: float = 0.0
			var damage_report = data.get("damage_report", null)
			if damage_report and damage_report is DamageReport:
				damage_taken = damage_report.get_total_damage_delta()
				damage_percent = damage_report.get_final_damage_percent()

			# Build stats result
			var stats_result = {
				"position": data.get("finish_position", 0),
				"track_id": track_id,
				"best_lap": data.get("lap_times", []).min() if data.get("lap_times", []).size() > 0 else 0.0,
				"lap_times": data.get("lap_times", []),
				"dnf": data.get("dnf", false),
				"damage_taken": damage_taken,
				"damage_percent": damage_percent,
				"reward": 0  # Reward is added separately in complete_race
			}

			PlayerProgress.record_race_stats(stats_result)

			# Update challenges
			if ChallengeManager:
				ChallengeManager.on_race_completed(stats_result)

			break

## Sync player's damage state to PlayerProgress for persistence
func _sync_player_damage() -> void:
	if not PlayerProgress or not DamageSystem:
		return

	# Find the player car (has use_player_upgrades = true)
	for car in registered_cars:
		if car.get("use_player_upgrades"):
			var damage_state = DamageSystem.get_damage_state(car)
			if damage_state:
				PlayerProgress.sync_damage_from_race(damage_state)
			break

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

	# Sync player damage before finishing
	_sync_player_damage()
	_finish_race()

## Get sorted race results
func get_race_results() -> Array:
	var results = []
	for car_id in car_data.keys():
		var data = car_data[car_id]
		var car = data["car"]

		# Get damage report for this car
		var damage_report: DamageReport = null
		if DamageSystem:
			damage_report = DamageSystem.finalize_race_report(car)

		results.append({
			"car_id": car_id,
			"car": car,
			"position": data["finish_position"],
			"total_time": data["finish_time"],
			"laps": data["laps"],
			"lap_times": data["lap_times"],
			"best_lap": data["lap_times"].min() if data["lap_times"].size() > 0 else 0.0,
			"dnf": data["dnf"],
			"dnf_reason": data["dnf_reason"],
			"damage_report": damage_report
		})

	# Sort: finished cars by position, DNF cars at the end
	results.sort_custom(func(a, b):
		# DNF cars go to the end
		if a["dnf"] != b["dnf"]:
			return not a["dnf"]  # Non-DNF first
		# Both DNF or both finished - sort by position (but DNF has -1)
		if a["dnf"]:
			return a["total_time"] < b["total_time"]  # DNFs by time
		return a["position"] < b["position"]
	)

	# Reassign positions for display (DNF gets last positions)
	var pos = 1
	for result in results:
		if result["dnf"]:
			result["position"] = -1  # Keep as DNF indicator
		else:
			result["position"] = pos
			pos += 1

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

# =============================================================================
# DNF / Car Totaling
# =============================================================================

## Handle car totaled signal from DamageSystem
func _on_car_totaled(car: Node, reason: String) -> void:
	if state != RaceState.RACING:
		return

	if not car is Car:
		return

	var car_id = car.car_id
	if car_id not in car_data:
		return

	var data = car_data[car_id]
	if data["finished"] or data["dnf"]:
		return

	# Mark as DNF
	var current_time = Time.get_ticks_msec() / 1000.0
	data["dnf"] = true
	data["dnf_reason"] = reason
	data["finished"] = true
	data["finish_time"] = current_time - race_start_time
	data["finish_position"] = -1  # -1 indicates DNF

	# Update damage report with DNF status
	if DamageSystem:
		var report = DamageSystem.get_damage_report(car)
		if report:
			report.is_dnf = true
			report.dnf_reason = reason

	car_dnf.emit(car, reason)

	# Check if race should end
	_check_race_complete()

## Check if a car is DNF
func is_car_dnf(car: Car) -> bool:
	if car.car_id not in car_data:
		return false
	return car_data[car.car_id]["dnf"]

## Get DNF reason for a car
func get_dnf_reason(car: Car) -> String:
	if car.car_id not in car_data:
		return ""
	return car_data[car.car_id]["dnf_reason"]
