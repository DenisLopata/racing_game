# StartLine.gd
extends Area2D

@export var lap_tracker: LapTracker

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("PlayerCar"):
		lap_tracker.on_crossed_line()
