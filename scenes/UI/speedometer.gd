class_name Speedometer
extends Control

@onready var hbox: HBoxContainer = $MarginContainer/HBoxContainer
@onready var lbl_speed: Label = $MarginContainer/HBoxContainer/lblSpeed
@onready var lbl_lap: Label = $MarginContainer/HBoxContainer/lblLap
@onready var lbl_lap_time: Label = $MarginContainer/HBoxContainer/lblLapTime
@onready var lbl_stats: Label = $MarginContainer/HBoxContainer/lblStats

var lbl_position: Label

func _ready() -> void:
	_setup_position_label()

func _setup_position_label() -> void:
	lbl_position = Label.new()
	lbl_position.text = "P1"
	hbox.add_child(lbl_position)
	hbox.move_child(lbl_position, 0)  # Move to front

func set_speed(speed: String) -> void:
	lbl_speed.text = speed

func set_lap(lap_number: String) -> void:
	lbl_lap.text = "Lap: " + lap_number

func set_lap_time(lap_time: String) -> void:
	lbl_lap_time.text = "Time: " + lap_time

func set_race_position(pos: int, total: int) -> void:
	if lbl_position:
		lbl_position.text = "P%d/%d" % [pos, total]

		# Color based on position
		match pos:
			1:
				lbl_position.add_theme_color_override("font_color", Color.GOLD)
			2:
				lbl_position.add_theme_color_override("font_color", Color.SILVER)
			3:
				lbl_position.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))
			_:
				lbl_position.add_theme_color_override("font_color", Color.WHITE)

func set_total_laps(current: int, total: int) -> void:
	lbl_lap.text = "Lap: %d/%d" % [current, total]

## Display car stats from part modifiers
func set_car_stats(modifiers: CarModifiers) -> void:
	if modifiers and lbl_stats:
		lbl_stats.text = "ACC:%.1f SPD:%.1f BRK:%.1f" % [
			modifiers.acceleration_mult,
			modifiers.max_speed_mult,
			modifiers.brake_mult
		]
