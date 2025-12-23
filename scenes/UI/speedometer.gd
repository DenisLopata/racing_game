class_name Speedometer
extends Control

@onready var lbl_speed: Label = $HBoxContainer/lblSpeed
@onready var lbl_lap: Label = $HBoxContainer/lblLap
@onready var lbl_lap_time: Label = $HBoxContainer/lblLapTime

func set_speed(speed: String) -> void:
	lbl_speed.text = speed

func set_lap(lap_number: String) -> void:
	lbl_lap.text = "Lap: " + lap_number

func set_lap_time(lap_time: String) -> void:
	lbl_lap_time.text = "Time: " + lap_time
