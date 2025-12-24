# StartLine.gd
extends Area2D

@export var lap_tracker: LapTracker

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	# Check if body is a Car
	if body is Car:
		var car = body as Car
		# Only count laps during racing
		if RaceManager.is_racing():
			RaceManager.on_car_crossed_line(car)

	# Legacy support for old lap tracker (player only)
	if body.is_in_group("PlayerCar") and lap_tracker != null:
		lap_tracker.on_crossed_line()
