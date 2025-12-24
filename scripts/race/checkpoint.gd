class_name Checkpoint
extends Area2D
## Individual checkpoint that detects when cars pass through

## The index of this checkpoint in the sequence (0, 1, 2, ...)
@export var checkpoint_index: int = 0

## Signal emitted when a car passes this checkpoint
signal car_passed(car: Car, checkpoint_index: int)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Set collision layer/mask for checkpoints
	collision_layer = 0
	collision_mask = 1  # Detect cars on layer 1

func _on_body_entered(body: Node) -> void:
	if body is Car:
		var car = body as Car
		car_passed.emit(car, checkpoint_index)
		RaceManager.on_car_checkpoint(car, checkpoint_index)
