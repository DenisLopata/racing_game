class_name CheckpointSystem
extends Node
## Manages all checkpoints on a track and tracks car progress

## All checkpoints in order
var checkpoints: Array[Checkpoint] = []

## Track progress per car: car_id -> last_checkpoint_index
var car_progress: Dictionary = {}

## Signal when a car completes a full lap of checkpoints
signal lap_checkpoints_complete(car: Car)

func _ready() -> void:
	# Find all Checkpoint children
	_collect_checkpoints()

func _collect_checkpoints() -> void:
	checkpoints.clear()
	for child in get_children():
		if child is Checkpoint:
			checkpoints.append(child)
			child.car_passed.connect(_on_checkpoint_passed)

	# Sort by checkpoint_index
	checkpoints.sort_custom(func(a, b): return a.checkpoint_index < b.checkpoint_index)

	print("CheckpointSystem: Found %d checkpoints" % checkpoints.size())

## Register a car to track
func register_car(car: Car) -> void:
	car_progress[car.car_id] = -1  # Start before checkpoint 0

## Get total number of checkpoints
func get_checkpoint_count() -> int:
	return checkpoints.size()

## Get a car's progress as a fraction (0.0 to 1.0)
func get_car_progress(car: Car) -> float:
	if car.car_id not in car_progress:
		return 0.0

	var last_checkpoint = car_progress[car.car_id]
	if checkpoints.size() == 0:
		return 0.0

	return float(last_checkpoint + 1) / float(checkpoints.size())

## Called when a car passes a checkpoint
func _on_checkpoint_passed(car: Car, checkpoint_index: int) -> void:
	if car.car_id not in car_progress:
		register_car(car)

	var expected_next = car_progress[car.car_id] + 1

	# Check if this is the expected next checkpoint
	if checkpoint_index == expected_next:
		car_progress[car.car_id] = checkpoint_index

		# Check if car completed all checkpoints (ready for lap)
		if checkpoint_index == checkpoints.size() - 1:
			# Car has passed all checkpoints, ready for finish line
			pass
	elif checkpoint_index == 0 and car_progress[car.car_id] == checkpoints.size() - 1:
		# Wrap around from last checkpoint to first (new lap)
		car_progress[car.car_id] = 0

## Reset a car's checkpoint progress (called when they cross finish line)
func reset_car_progress(car: Car) -> void:
	if car.car_id in car_progress:
		car_progress[car.car_id] = -1

## Check if a car has passed all checkpoints (valid lap)
func is_lap_valid(car: Car) -> bool:
	if car.car_id not in car_progress:
		return false

	# Car should have passed the last checkpoint
	return car_progress[car.car_id] >= checkpoints.size() - 1

## Add a checkpoint dynamically
func add_checkpoint(checkpoint: Checkpoint) -> void:
	checkpoints.append(checkpoint)
	checkpoint.car_passed.connect(_on_checkpoint_passed)
	checkpoints.sort_custom(func(a, b): return a.checkpoint_index < b.checkpoint_index)
