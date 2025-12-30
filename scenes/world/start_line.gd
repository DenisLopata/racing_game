# StartLine.gd
extends Area2D

@export var lap_tracker: LapTracker
@export var checkpoint_system: CheckpointSystem

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	# Check if body is a Car
	if body is Car:
		var car = body as Car
		# Only count laps during racing
		if RaceManager.is_racing():
			var checkpoint_count = checkpoint_system.get_checkpoint_count() if checkpoint_system else 0
			RaceManager.on_car_crossed_line(car, checkpoint_count)

	# Legacy support for old lap tracker (player only)
	if body.is_in_group("PlayerCar") and lap_tracker != null:
		lap_tracker.on_crossed_line()
