extends Node2D

@onready var tire_marks_line_2d: Line2D = $TireMarksLine2D
@onready var car: CharacterBody2D = $Car
@onready var surface_manager: SurfaceManager = $SurfaceManager
@onready var speedometer: Speedometer = %Speedometer
@onready var lap_tracker: LapTracker = $LapTracker

func _ready() -> void:
	car.tire_marks = tire_marks_line_2d
	car.surface_manager = surface_manager
	
	car.drift_marks_finished.connect(_on_car_drift_marks_finished)
	car.update_speed.connect(_on_car_update_speed)
	lap_tracker.lap_completed.connect(_on_lap_tracker_lap_completed)
	lap_tracker.race_finished.connect(_on_lap_tracker_race_finished)

func _on_lap_tracker_lap_completed(lap_number: int, lap_time: float) -> void:
	speedometer.set_lap(str(lap_number))
	speedometer.set_lap_time(str(lap_time))
	
func _on_lap_tracker_race_finished(lap_times: Array) -> void:
	#speedometer.set_speed(speed)
	pass
	
func _on_car_update_speed(speed: String) -> void:
	speedometer.set_speed(speed)
	
func _on_car_drift_marks_finished(points: PackedVector2Array) -> void:
	if points.size() < 2:
		return
	
	var skid = Line2D.new()
	skid.width = 2
	skid.default_color = Color(0,0,0,0.6) # dark grey
	skid.points = points.duplicate()      # copy so it doesn’t get cleared
	skid.modulate.a = 0.2;
	skid.width = 10;
	add_child(skid)

	# Optional: move to a dedicated "Skidmarks" Node2D layer
	#$Skidmarks.add_child(skid)
