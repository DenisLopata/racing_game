class_name LapTracker
extends Node

@export var total_laps: int = 300

var current_lap: int = 0
var lap_start_time: float = 0.0
var lap_times: Array = []

signal lap_completed(lap_number: int, lap_time: float)
signal race_finished(lap_times: Array)

func start_race() -> void:
	current_lap = 1
	lap_start_time = Time.get_ticks_msec() / 1000.0  # convert to seconds
	lap_times.clear()

func on_crossed_line() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	var lap_time = now - lap_start_time
	lap_times.append(lap_time)
	lap_completed.emit(current_lap, lap_time)

	if current_lap >= total_laps:
		race_finished.emit(lap_times)
	else:
		current_lap += 1
		lap_start_time = now
